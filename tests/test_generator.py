"""Unit tests for deterministic B2B SaaS synthetic dataset generation."""

from __future__ import annotations

import pandas as pd

from saas_revenue.generator import generate_saas_dataset


def test_generator_is_deterministic() -> None:
    ds1 = generate_saas_dataset(num_accounts=40, seed=123, inject_anomalies=True)
    ds2 = generate_saas_dataset(num_accounts=40, seed=123, inject_anomalies=True)

    pd.testing.assert_frame_equal(ds1.accounts, ds2.accounts)
    pd.testing.assert_frame_equal(ds1.subscriptions, ds2.subscriptions)
    pd.testing.assert_frame_equal(ds1.invoices, ds2.invoices)
    pd.testing.assert_frame_equal(ds1.marketing_spend, ds2.marketing_spend)


def test_generator_produces_expected_entities_and_anomalies() -> None:
    ds = generate_saas_dataset(num_accounts=60, seed=42, inject_anomalies=True)

    assert len(ds.accounts) == 60
    assert len(ds.subscriptions) > 60
    assert len(ds.invoices) > 60
    assert len(ds.marketing_spend) > 0
    # Verify controlled anomalies exist so quarantine gate is exercised
    assert (ds.subscriptions["mrr_amount"] < 0).any()
    assert ds.subscriptions["account_id"].isna().any()
