"""Deterministic B2B SaaS synthetic dataset generator with realistic lifecycle & anomalies."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

import numpy as np
import pandas as pd

PLAN_CATALOG: dict[str, tuple[str, float]] = {
    "starter": ("Starter", 199.0),
    "growth": ("Growth", 599.0),
    "scale": ("Scale", 1499.0),
    "enterprise": ("Enterprise", 3999.0),
}

PLAN_ORDER = ["starter", "growth", "scale", "enterprise"]
SEGMENTS = ["SMB", "Mid-Market", "Enterprise"]
INDUSTRIES = ["FinTech", "E-commerce", "HealthTech", "Logistics", "EdTech", "Cybersecurity"]
COUNTRIES = ["BR", "US", "UK", "DE", "CA", "MX"]
CHANNELS = ["Organic Search", "Outbound Sales", "Paid Search", "Partner Referral", "Product-Led"]


@dataclass(frozen=True)
class RawSaaSDataset:
    """Container for all raw B2B SaaS tables."""

    accounts: pd.DataFrame
    subscriptions: pd.DataFrame
    invoices: pd.DataFrame
    marketing_spend: pd.DataFrame


def _month_starts(start_ym: str = "2024-07-01", periods: int = 18) -> list[date]:
    return [d.date() for d in pd.date_range(start=start_ym, periods=periods, freq="MS")]


def generate_saas_dataset(
    num_accounts: int = 250,
    seed: int = 42,
    inject_anomalies: bool = True,
) -> RawSaaSDataset:
    """Generate a deterministic, realistic 18-month B2B SaaS dataset.

    Includes:
    - Organic account growth across 18 months
    - Subscription lifecycle events: New, Expansion, Contraction, Churn, and Reactivation
    - Realistic invoices with payment statuses
    - Monthly marketing spend per channel & segment (for CAC / LTV / Payback)
    - Controlled raw data anomalies (duplicates, negative MRR, null FK) to test WAP quarantine
    """
    rng = np.random.default_rng(seed)
    months = _month_starts("2024-07-01", periods=18)

    account_rows: list[dict] = []
    subscription_rows: list[dict] = []
    invoice_rows: list[dict] = []

    sub_counter = 1
    inv_counter = 1

    for idx in range(1, num_accounts + 1):
        account_id = f"ACC-{idx:05d}"
        segment = str(rng.choice(SEGMENTS, p=[0.55, 0.30, 0.15]))
        industry = str(rng.choice(INDUSTRIES))
        country = str(rng.choice(COUNTRIES, p=[0.35, 0.30, 0.10, 0.10, 0.08, 0.07]))
        channel = str(rng.choice(CHANNELS, p=[0.28, 0.22, 0.20, 0.15, 0.15]))

        # Spread account signups across all 18 months so every month has realistic acquisition & CAC
        signup_idx = int(rng.integers(0, len(months)))
        signup_month = months[signup_idx]

        account_rows.append(
            {
                "account_id": account_id,
                "company_name": f"{industry} Corp {idx:03d}",
                "segment": segment,
                "industry": industry,
                "country": country,
                "acquisition_channel": channel,
                "created_at": signup_month.isoformat(),
            }
        )

        # Initial plan depends on segment
        if segment == "SMB":
            plan_idx = int(rng.choice([0, 1], p=[0.75, 0.25]))
        elif segment == "Mid-Market":
            plan_idx = int(rng.choice([1, 2], p=[0.65, 0.35]))
        else:
            plan_idx = int(rng.choice([2, 3], p=[0.40, 0.60]))

        active = True
        churned_once = False
        sub_id = f"SUB-{sub_counter:06d}"
        sub_counter += 1
        current_start = signup_month

        for m_idx in range(signup_idx, len(months)):
            month_dt = months[m_idx]
            plan_key = PLAN_ORDER[plan_idx]
            plan_name, base_price = PLAN_CATALOG[plan_key]

            if active:
                # Record active subscription snapshot for this month
                seats = int(rng.integers(2, 15)) if plan_idx < 2 else int(rng.integers(15, 60))
                seat_addon = float((seats // 10) * 50.0)
                mrr_amount = round(base_price + seat_addon, 2)

                subscription_rows.append(
                    {
                        "subscription_id": sub_id,
                        "account_id": account_id,
                        "plan_tier": plan_name,
                        "status": "active",
                        "mrr_amount": mrr_amount,
                        "seats": seats,
                        "billing_month": month_dt.isoformat(),
                        "subscription_start_date": current_start.isoformat(),
                        "updated_at": f"{month_dt.isoformat()}T12:00:00",
                    }
                )

                inv_status = str(
                    rng.choice(["paid", "paid", "paid", "past_due"], p=[0.90, 0.05, 0.03, 0.02])
                )
                invoice_rows.append(
                    {
                        "invoice_id": f"INV-{inv_counter:07d}",
                        "subscription_id": sub_id,
                        "account_id": account_id,
                        "billing_month": month_dt.isoformat(),
                        "amount_due": mrr_amount,
                        "amount_paid": mrr_amount if inv_status == "paid" else 0.0,
                        "invoice_status": inv_status,
                        "issued_at": f"{month_dt.isoformat()}T08:00:00",
                    }
                )
                inv_counter += 1

                # Decide next month lifecycle transition
                roll = float(rng.random())
                churn_prob = (
                    0.055 if segment == "SMB" else (0.030 if segment == "Mid-Market" else 0.015)
                )
                upgrade_prob = 0.075 if plan_idx < len(PLAN_ORDER) - 1 else 0.0
                downgrade_prob = 0.030 if plan_idx > 0 else 0.0

                if roll < churn_prob:
                    active = False
                    churned_once = True
                elif roll < churn_prob + upgrade_prob:
                    plan_idx = min(plan_idx + 1, len(PLAN_ORDER) - 1)
                elif roll < churn_prob + upgrade_prob + downgrade_prob:
                    plan_idx = max(plan_idx - 1, 0)
            else:
                # Possibility of reactivation after churn
                if churned_once and float(rng.random()) < 0.08:
                    active = True
                    sub_id = f"SUB-{sub_counter:06d}"
                    sub_counter += 1
                    current_start = month_dt

    # Monthly marketing spend per segment & channel
    spend_rows: list[dict] = []
    spend_id = 1
    for month_dt in months:
        for segment in SEGMENTS:
            base_seg = (
                4500.0 if segment == "SMB" else (7500.0 if segment == "Mid-Market" else 11000.0)
            )
            for channel in CHANNELS:
                channel_mult = (
                    0.35
                    if channel == "Organic Search"
                    else (1.4 if channel == "Outbound Sales" else 1.0)
                )
                spend_amount = round(float(base_seg * channel_mult * rng.uniform(0.85, 1.15)), 2)
                spend_rows.append(
                    {
                        "spend_id": f"SPD-{spend_id:06d}",
                        "spend_month": month_dt.isoformat(),
                        "segment": segment,
                        "acquisition_channel": channel,
                        "spend_amount": spend_amount,
                    }
                )
                spend_id += 1

    accounts_df = pd.DataFrame(account_rows)
    subscriptions_df = pd.DataFrame(subscription_rows)
    invoices_df = pd.DataFrame(invoice_rows)
    marketing_spend_df = pd.DataFrame(spend_rows)

    if inject_anomalies and len(subscriptions_df) > 5:
        # Inject realistic dirty data to prove Write-Audit-Publish quarantine works:
        # 1) Negative MRR corruption
        bad_neg = subscriptions_df.iloc[[0]].copy()
        bad_neg["subscription_id"] = "SUB-CORRUPT-NEG"
        bad_neg["mrr_amount"] = -250.0

        # 2) Null account_id orphan record
        bad_null = subscriptions_df.iloc[[1]].copy()
        bad_null["subscription_id"] = "SUB-CORRUPT-NULL"
        bad_null["account_id"] = None

        # 3) Exact duplicate subscription-month row (to be deduplicated/quarantined)
        dup_row = subscriptions_df.iloc[[2]].copy()

        subscriptions_df = pd.concat(
            [subscriptions_df, bad_neg, bad_null, dup_row], ignore_index=True
        )

    return RawSaaSDataset(
        accounts=accounts_df,
        subscriptions=subscriptions_df,
        invoices=invoices_df,
        marketing_spend=marketing_spend_df,
    )
