"""Tests for Pandera Data Contracts and Write-Audit-Publish quarantine routing."""

from __future__ import annotations

from saas_revenue.contracts import SUBSCRIPTIONS_SCHEMA, audit_and_quarantine
from saas_revenue.generator import generate_saas_dataset


def test_wap_quarantines_negative_null_and_duplicate_subscriptions() -> None:
    ds = generate_saas_dataset(num_accounts=50, seed=42, inject_anomalies=True)

    result = audit_and_quarantine(
        df=ds.subscriptions,
        schema=SUBSCRIPTIONS_SCHEMA,
        table_name="subscriptions",
        dedup_subset=["account_id", "billing_month"],
    )

    # Exactly 3 injected dirty records: negative MRR, null account_id, and duplicate key
    assert result.quarantined_count == 3
    assert (result.valid_df["mrr_amount"] > 0).all()
    assert result.valid_df["account_id"].notna().all()
    assert not result.valid_df.duplicated(subset=["account_id", "billing_month"]).any()
    assert "quarantine_reason" in result.quarantined_df.columns
    assert result.quarantined_df["quarantine_reason"].str.len().gt(0).all()
