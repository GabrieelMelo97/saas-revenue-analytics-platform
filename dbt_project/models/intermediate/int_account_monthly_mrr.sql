with calendar_months as (
    select distinct revenue_month
    from {{ ref('stg_subscriptions') }}
),

account_bounds as (
    select
        account_id,
        min(revenue_month) as first_active_month
    from {{ ref('stg_subscriptions') }}
    group by 1
),

account_spine as (
    select
        b.account_id,
        b.first_active_month,
        c.revenue_month
    from account_bounds as b
    inner join calendar_months as c
        on c.revenue_month >= b.first_active_month
),

joined as (
    select
        s.account_id,
        s.first_active_month,
        s.revenue_month,
        coalesce(sub.plan_tier, 'Churned') as plan_tier,
        coalesce(sub.seats, 0) as seats,
        coalesce(sub.mrr_amount, 0.0) as ending_mrr
    from account_spine as s
    left join {{ ref('stg_subscriptions') }} as sub
        on s.account_id = sub.account_id
        and s.revenue_month = sub.revenue_month
)

select
    account_id,
    first_active_month,
    revenue_month,
    plan_tier,
    seats,
    cast(
        coalesce(
            lag(ending_mrr) over (partition by account_id order by revenue_month),
            0.0
        ) as {{ dbt.type_float() }}
    ) as beginning_mrr,
    cast(ending_mrr as {{ dbt.type_float() }}) as ending_mrr
from joined
