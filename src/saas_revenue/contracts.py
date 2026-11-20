"""Pandera Data Contracts and Write-Audit-Publish (WAP) quarantine logic."""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd
import pandera as pa
from pandera import Check, Column, DataFrameSchema

ACCOUNTS_SCHEMA = DataFrameSchema(
    {
        "account_id": Column(str, nullable=False, unique=True, checks=Check.str_startswith("ACC-")),
        "company_name": Column(str, nullable=False),
        "segment": Column(
            str, nullable=False, checks=Check.isin(["SMB", "Mid-Market", "Enterprise"])
        ),
        "industry": Column(str, nullable=False),
        "country": Column(str, nullable=False),
        "acquisition_channel": Column(str, nullable=False),
        "created_at": Column(str, nullable=False),
    },
    strict=True,
)

SUBSCRIPTIONS_SCHEMA = DataFrameSchema(
    {
        "subscription_id": Column(str, nullable=False),
        "account_id": Column(str, nullable=False, checks=Check.str_startswith("ACC-")),
        "plan_tier": Column(
            str,
            nullable=False,
            checks=Check.isin(["Starter", "Growth", "Scale", "Enterprise"]),
        ),
        "status": Column(str, nullable=False, checks=Check.isin(["active", "canceled", "paused"])),
        "mrr_amount": Column(float, nullable=False, checks=Check.greater_than(0.0)),
        "seats": Column(int, nullable=False, checks=Check.greater_than_or_equal_to(1)),
        "billing_month": Column(str, nullable=False),
        "subscription_start_date": Column(str, nullable=False),
        "updated_at": Column(str, nullable=False),
    },
    strict=True,
)

INVOICES_SCHEMA = DataFrameSchema(
    {
        "invoice_id": Column(str, nullable=False, unique=True),
        "subscription_id": Column(str, nullable=False),
        "account_id": Column(str, nullable=False),
        "billing_month": Column(str, nullable=False),
        "amount_due": Column(float, nullable=False, checks=Check.greater_than_or_equal_to(0.0)),
        "amount_paid": Column(float, nullable=False, checks=Check.greater_than_or_equal_to(0.0)),
        "invoice_status": Column(
            str, nullable=False, checks=Check.isin(["paid", "past_due", "open", "void"])
        ),
        "issued_at": Column(str, nullable=False),
    },
    strict=True,
)

MARKETING_SPEND_SCHEMA = DataFrameSchema(
    {
        "spend_id": Column(str, nullable=False, unique=True),
        "spend_month": Column(str, nullable=False),
        "segment": Column(
            str, nullable=False, checks=Check.isin(["SMB", "Mid-Market", "Enterprise"])
        ),
        "acquisition_channel": Column(str, nullable=False),
        "spend_amount": Column(float, nullable=False, checks=Check.greater_than_or_equal_to(0.0)),
    },
    strict=True,
)


@dataclass(frozen=True)
class AuditResult:
    """Result of Write-Audit-Publish contract validation."""

    table_name: str
    valid_df: pd.DataFrame
    quarantined_df: pd.DataFrame

    @property
    def total_rows(self) -> int:
        return len(self.valid_df) + len(self.quarantined_df)

    @property
    def quarantined_count(self) -> int:
        return len(self.quarantined_df)


def audit_and_quarantine(
    df: pd.DataFrame,
    schema: DataFrameSchema,
    table_name: str,
    dedup_subset: list[str] | None = None,
) -> AuditResult:
    """Validate a DataFrame against a Pandera contract, routing bad/duplicate rows to quarantine.

    Implements the Audit gate of the Write-Audit-Publish (WAP) pattern:
    - Detects duplicate business keys (if `dedup_subset` is provided)
    - Runs lazy Pandera validation to capture every failing row index
    - Quarantines failing rows with an explicit `quarantine_reason` column
    - Re-validates the clean DataFrame strictly before returning
    """
    working = df.copy().reset_index(drop=True)
    quarantine_reasons: dict[int, list[str]] = {}

    if dedup_subset:
        dup_mask = working.duplicated(subset=dedup_subset, keep="first")
        for idx in working.index[dup_mask]:
            quarantine_reasons.setdefault(int(idx), []).append(
                f"duplicate_key:{'+'.join(dedup_subset)}"
            )

    try:
        schema.validate(working, lazy=True)
    except pa.errors.SchemaErrors as exc:
        failure_cases = exc.failure_cases
        for _, case in failure_cases.iterrows():
            raw_idx = case.get("index")
            if pd.notna(raw_idx):
                try:
                    row_idx = int(raw_idx)
                    col = str(case.get("column", "table"))
                    chk = str(case.get("check", "schema_error"))
                    quarantine_reasons.setdefault(row_idx, []).append(f"{col}:{chk}")
                except (ValueError, TypeError):
                    continue

    bad_indices = sorted(quarantine_reasons.keys())
    if bad_indices:
        quarantined = working.loc[bad_indices].copy()
        quarantined["quarantine_reason"] = [
            "; ".join(sorted(set(quarantine_reasons[i]))) for i in bad_indices
        ]
        valid = working.drop(index=bad_indices).reset_index(drop=True)
    else:
        quarantined = working.iloc[0:0].copy()
        quarantined["quarantine_reason"] = pd.Series(dtype=str)
        valid = working

    # Final strict validation gate: guaranteed contract compliance before Publish
    validated_clean = schema.validate(valid)

    return AuditResult(
        table_name=table_name,
        valid_df=validated_clean,
        quarantined_df=quarantined.reset_index(drop=True),
    )
