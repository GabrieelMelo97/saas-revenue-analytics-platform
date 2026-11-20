with monthly_revenue as (
    select
        revenue_month,
        segment,
        count(distinct case when ending_mrr > 0 then account_id end) as active_accounts,
        count(distinct case when movement_type = 'new' then account_id end) as new_accounts,
        count(distinct case when movement_type = 'churn' then account_id end) as churned_accounts,
        sum(ending_mrr) as total_mrr
    from {{ ref('fct_mrr_waterfall') }}
    group by 1, 2
),

monthly_spend as (
    select
        spend_month as revenue_month,
        segment,
        sum(spend_amount) as marketing_spend
    from {{ ref('stg_marketing_spend') }}
    group by 1, 2
),

combined as (
    select
        r.revenue_month,
        r.segment,
        r.active_accounts,
        r.new_accounts,
        r.churned_accounts,
        round(r.total_mrr, 2) as total_mrr,
        round(coalesce(s.marketing_spend, 0.0), 2) as marketing_spend,
        round(r.total_mrr / nullif(r.active_accounts, 0), 2) as arpa,
        round(coalesce(s.marketing_spend, 0.0) / nullif(r.new_accounts, 0), 2) as cac,
        -- Monthly logo churn rate floored at 2% to avoid infinite LTV in zero-churn months
        greatest(
            cast(r.churned_accounts as {{ dbt.type_float() }}) / nullif(r.active_accounts, 0),
            0.02
        ) as effective_monthly_churn_rate
    from monthly_revenue as r
    left join monthly_spend as s
        on r.revenue_month = s.revenue_month
        and r.segment = s.segment
)

select
    concat(
        cast(revenue_month as {{ dbt.type_string() }}),
        '_',
        segment
    ) as unit_economics_sk,
    revenue_month,
    segment,
    cast(active_accounts as {{ dbt.type_int() }}) as active_accounts,
    cast(new_accounts as {{ dbt.type_int() }}) as new_accounts,
    cast(total_mrr as {{ dbt.type_float() }}) as total_mrr,
    cast(marketing_spend as {{ dbt.type_float() }}) as marketing_spend,
    cast(coalesce(arpa, 0.0) as {{ dbt.type_float() }}) as arpa,
    cast(coalesce(cac, 0.0) as {{ dbt.type_float() }}) as cac,
    -- LTV assuming 80% SaaS Gross Margin: (ARPA * 0.80) / effective_monthly_churn_rate
    cast(
        round((coalesce(arpa, 0.0) * 0.80) / effective_monthly_churn_rate, 2)
        as {{ dbt.type_float() }}
    ) as estimated_ltv,
    cast(
        round(
            ((coalesce(arpa, 0.0) * 0.80) / effective_monthly_churn_rate) / nullif(cac, 0),
            2
        )
        as {{ dbt.type_float() }}
    ) as ltv_to_cac_ratio,
    cast(
        round(cac / nullif(coalesce(arpa, 0.0) * 0.80, 0), 1)
        as {{ dbt.type_float() }}
    ) as cac_payback_months
from combined
