-- Singular Business Rule Test:
-- No MRR component in the governed waterfall may ever be negative.

select
    mrr_waterfall_id,
    account_id,
    revenue_month
from {{ ref('fct_mrr_waterfall') }}
where beginning_mrr < 0
    or new_mrr < 0
    or expansion_mrr < 0
    or reactivation_mrr < 0
    or contraction_mrr < 0
    or churned_mrr < 0
    or ending_mrr < 0
