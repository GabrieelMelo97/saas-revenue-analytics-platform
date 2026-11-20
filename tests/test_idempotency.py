"""Integration tests verifying idempotent ingestion into local DuckDB."""

from __future__ import annotations

from pathlib import Path

import duckdb

from saas_revenue.config import Settings
from saas_revenue.ingest import run_ingestion


def test_ingestion_is_idempotent(tmp_path: Path) -> None:
    settings = Settings(
        app_env="local",
        target_backend="local",
        local_duckdb_path=tmp_path / "warehouse" / "test.duckdb",
        local_data_dir=tmp_path / "raw",
        local_quarantine_dir=tmp_path / "quarantine",
        generator_seed=42,
        num_accounts=40,
    )

    summary_first = run_ingestion(settings)
    summary_second = run_ingestion(settings)

    assert summary_first == summary_second
    assert summary_first["subscriptions"]["quarantined_rows"] == 3

    with duckdb.connect(str(settings.local_duckdb_path), read_only=True) as conn:
        count_accounts = conn.execute("SELECT COUNT(*) FROM raw.accounts").fetchone()[0]
        count_subs = conn.execute("SELECT COUNT(*) FROM raw.subscriptions").fetchone()[0]

    assert count_accounts == 40
    assert count_subs == summary_first["subscriptions"]["valid_rows"]
