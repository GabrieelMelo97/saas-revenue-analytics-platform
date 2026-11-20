-- Singular Financial Reconciliation Test:
-- Accounting invariant: beginning_mrr + new + expansion + reactivation - contraction - churn == ending_mrr
-- Fails if ANY account-month diverges by more than 1 cent (0.01).

select
    mrr_waterfall_id,
    account_id,
    revenue_month,
    beginning_mrr,
    new_mrr,
    expansion_mrr,
    reactivation_mrr,
    contraction_mrr,
    churned_mrr,
    ending_mrr,
    round(
        (beginning_mrr + new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr)
        - ending_mrr,
        4
    ) as reconciliation_diff
from {{ ref('fct_mrr_waterfall') }}
where abs(
    (beginning_mrr + new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr)
    - ending_mrr
) > 0.01
