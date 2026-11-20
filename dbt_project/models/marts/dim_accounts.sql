with account_metrics as (
    select
        account_id,
        min(first_active_month) as first_active_month,
        max(case when ending_mrr > 0 then revenue_month end) as last_active_month,
        round(sum(ending_mrr), 2) as lifetime_billed_mrr,
        sum(case when movement_type = 'expansion' then 1 else 0 end) as expansion_events,
        sum(case when movement_type = 'churn' then 1 else 0 end) as churn_events
    from {{ ref('int_mrr_movements') }}
    group by 1
),

latest_month as (
    select
        account_id,
        plan_tier as current_plan_tier,
        ending_mrr as current_mrr,
        case when ending_mrr > 0 then 'active' else 'churned' end as current_status
    from {{ ref('int_mrr_movements') }}
    where revenue_month = (select max(revenue_month) from {{ ref('int_mrr_movements') }})
)

select
    a.account_id,
    a.company_name,
    a.segment,
    a.industry,
    a.country,
    a.acquisition_channel,
    a.signup_month,
    m.first_active_month,
    m.last_active_month,
    coalesce(l.current_plan_tier, 'Churned') as current_plan_tier,
    coalesce(l.current_status, 'churned') as current_status,
    cast(coalesce(l.current_mrr, 0.0) as {{ dbt.type_float() }}) as current_mrr,
    cast(coalesce(m.lifetime_billed_mrr, 0.0) as {{ dbt.type_float() }}) as lifetime_billed_mrr,
    cast(coalesce(m.expansion_events, 0) as {{ dbt.type_int() }}) as expansion_events,
    cast(coalesce(m.churn_events, 0) as {{ dbt.type_int() }}) as churn_events
from {{ ref('stg_accounts') }} as a
left join account_metrics as m
    on a.account_id = m.account_id
left join latest_month as l
    on a.account_id = l.account_id
