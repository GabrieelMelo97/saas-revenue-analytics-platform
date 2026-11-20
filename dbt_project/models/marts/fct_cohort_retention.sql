with cohort_base as (
    select
        first_active_month as cohort_month,
        count(distinct account_id) as cohort_accounts,
        sum(ending_mrr) as cohort_initial_mrr
    from {{ ref('fct_mrr_waterfall') }}
    where revenue_month = first_active_month
        and ending_mrr > 0
    group by 1
),

cohort_activity as (
    select
        w.first_active_month as cohort_month,
        {{ month_diff('w.first_active_month', 'w.revenue_month') }} as months_since_signup,
        count(distinct case when w.ending_mrr > 0 then w.account_id end) as retained_accounts,
        sum(w.ending_mrr) as retained_mrr
    from {{ ref('fct_mrr_waterfall') }} as w
    group by 1, 2
)

select
    concat(
        cast(a.cohort_month as {{ dbt.type_string() }}),
        '_m',
        cast(a.months_since_signup as {{ dbt.type_string() }})
    ) as cohort_period_sk,
    a.cohort_month,
    a.months_since_signup,
    cast(b.cohort_accounts as {{ dbt.type_int() }}) as cohort_accounts,
    cast(a.retained_accounts as {{ dbt.type_int() }}) as retained_accounts,
    cast(round(b.cohort_initial_mrr, 2) as {{ dbt.type_float() }}) as cohort_initial_mrr,
    cast(round(a.retained_mrr, 2) as {{ dbt.type_float() }}) as retained_mrr,
    cast(
        round((cast(a.retained_accounts as {{ dbt.type_float() }}) / nullif(b.cohort_accounts, 0)) * 100.0, 2)
        as {{ dbt.type_float() }}
    ) as logo_retention_pct,
    cast(
        round((a.retained_mrr / nullif(b.cohort_initial_mrr, 0)) * 100.0, 2)
        as {{ dbt.type_float() }}
    ) as net_dollar_retention_pct
from cohort_activity as a
inner join cohort_base as b
    on a.cohort_month = b.cohort_month
