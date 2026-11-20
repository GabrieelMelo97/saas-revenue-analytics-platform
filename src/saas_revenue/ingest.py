"""Idempotent Write-Audit-Publish (WAP) ingestion into DuckDB (local) or GCS + BigQuery (GCP)."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import duckdb

from saas_revenue.config import Settings, get_settings
from saas_revenue.contracts import (
    ACCOUNTS_SCHEMA,
    INVOICES_SCHEMA,
    MARKETING_SPEND_SCHEMA,
    SUBSCRIPTIONS_SCHEMA,
    AuditResult,
    audit_and_quarantine,
)
from saas_revenue.generator import generate_saas_dataset

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("saas_revenue.ingest")


def _publish_to_duckdb(duckdb_path: Path, results: list[AuditResult]) -> None:
    """Idempotently replace raw tables in local DuckDB warehouse."""
    duckdb_path.parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(duckdb_path)) as conn:
        conn.execute("CREATE SCHEMA IF NOT EXISTS raw;")
        for res in results:
            conn.register("tmp_valid_df", res.valid_df)
            conn.execute(
                f"CREATE OR REPLACE TABLE raw.{res.table_name} AS SELECT * FROM tmp_valid_df;"
            )
            conn.unregister("tmp_valid_df")
            logger.info(
                "Published raw.%s to DuckDB (%d valid rows, %d quarantined)",
                res.table_name,
                len(res.valid_df),
                res.quarantined_count,
            )


def _publish_to_gcp(settings: Settings, results: list[AuditResult]) -> None:
    """Idempotently upload Parquet files to GCS and load into BigQuery raw dataset."""
    from google.cloud import bigquery, storage

    storage_client = storage.Client(project=settings.gcp_project_id)
    bq_client = bigquery.Client(project=settings.gcp_project_id)
    bucket = storage_client.bucket(settings.gcp_raw_bucket)

    for res in results:
        local_parquet = settings.local_data_dir / f"{res.table_name}.parquet"
        res.valid_df.to_parquet(local_parquet, index=False)

        blob_path = f"raw/{res.table_name}/{res.table_name}.parquet"
        bucket.blob(blob_path).upload_from_filename(str(local_parquet))

        table_id = f"{settings.gcp_project_id}.{settings.gcp_bq_dataset_raw}.{res.table_name}"
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.PARQUET,
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        )
        load_job = bq_client.load_table_from_uri(
            f"gs://{settings.gcp_raw_bucket}/{blob_path}",
            table_id,
            job_config=job_config,
        )
        load_job.result()
        logger.info(
            "Published %s to BigQuery (%d valid rows, %d quarantined)",
            table_id,
            len(res.valid_df),
            res.quarantined_count,
        )


def run_ingestion(settings: Settings | None = None) -> dict[str, dict[str, int]]:
    """Run full Write-Audit-Publish ingestion pipeline and return audit summary."""
    cfg = settings or get_settings()
    cfg.local_data_dir.mkdir(parents=True, exist_ok=True)
    cfg.local_quarantine_dir.mkdir(parents=True, exist_ok=True)

    logger.info(
        "Starting ingestion | env=%s backend=%s seed=%d accounts=%d",
        cfg.app_env,
        cfg.target_backend,
        cfg.generator_seed,
        cfg.num_accounts,
    )

    raw_dataset = generate_saas_dataset(
        num_accounts=cfg.num_accounts,
        seed=cfg.generator_seed,
        inject_anomalies=True,
    )

    audit_specs = [
        ("accounts", raw_dataset.accounts, ACCOUNTS_SCHEMA, ["account_id"]),
        (
            "subscriptions",
            raw_dataset.subscriptions,
            SUBSCRIPTIONS_SCHEMA,
            ["account_id", "billing_month"],
        ),
        ("invoices", raw_dataset.invoices, INVOICES_SCHEMA, ["invoice_id"]),
        ("marketing_spend", raw_dataset.marketing_spend, MARKETING_SPEND_SCHEMA, ["spend_id"]),
    ]

    results: list[AuditResult] = []
    summary: dict[str, dict[str, int]] = {}

    for table_name, df, schema, dedup_keys in audit_specs:
        res = audit_and_quarantine(
            df=df, schema=schema, table_name=table_name, dedup_subset=dedup_keys
        )
        results.append(res)

        # Persist raw Parquet & quarantine CSV for auditability
        res.valid_df.to_parquet(cfg.local_data_dir / f"{table_name}.parquet", index=False)
        if res.quarantined_count > 0:
            q_path = cfg.local_quarantine_dir / f"{table_name}_quarantine.csv"
            res.quarantined_df.to_csv(q_path, index=False)
            logger.warning(
                "Quarantined %d invalid rows for %s -> %s",
                res.quarantined_count,
                table_name,
                q_path,
            )

        summary[table_name] = {
            "total_rows": res.total_rows,
            "valid_rows": len(res.valid_df),
            "quarantined_rows": res.quarantined_count,
        }

    # Write machine-readable audit report
    report = {
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "backend": cfg.target_backend,
        "tables": summary,
    }
    (cfg.local_quarantine_dir / "ingestion_audit_report.json").write_text(
        json.dumps(report, indent=2),
        encoding="utf-8",
    )

    if cfg.target_backend == "gcp":
        _publish_to_gcp(cfg, results)
    else:
        _publish_to_duckdb(cfg.local_duckdb_path, results)

    logger.info("Ingestion completed successfully | summary=%s", summary)
    return summary


if __name__ == "__main__":
    run_ingestion()
