with base as (
    select
        account_id,
        first_active_month,
        revenue_month,
        plan_tier,
        seats,
        beginning_mrr,
        ending_mrr
    from {{ ref('int_account_monthly_mrr') }}
),

classified as (
    select
        concat(
            cast(account_id as {{ dbt.type_string() }}),
            '_',
            cast(revenue_month as {{ dbt.type_string() }})
        ) as mrr_waterfall_id,
        account_id,
        first_active_month,
        revenue_month,
        plan_tier,
        seats,
        beginning_mrr,
        ending_mrr,

        case
            when revenue_month = first_active_month and ending_mrr > 0
                then ending_mrr
            else 0.0
        end as new_mrr,

        case
            when revenue_month > first_active_month
                and beginning_mrr = 0
                and ending_mrr > 0
                then ending_mrr
            else 0.0
        end as reactivation_mrr,

        case
            when beginning_mrr > 0 and ending_mrr > beginning_mrr
                then round(ending_mrr - beginning_mrr, 2)
            else 0.0
        end as expansion_mrr,

        case
            when beginning_mrr > 0 and ending_mrr > 0 and ending_mrr < beginning_mrr
                then round(beginning_mrr - ending_mrr, 2)
            else 0.0
        end as contraction_mrr,

        case
            when beginning_mrr > 0 and ending_mrr = 0
                then beginning_mrr
            else 0.0
        end as churned_mrr,

        case
            when revenue_month = first_active_month and ending_mrr > 0 then 'new'
            when revenue_month > first_active_month and beginning_mrr = 0 and ending_mrr > 0 then 'reactivation'
            when beginning_mrr > 0 and ending_mrr > beginning_mrr then 'expansion'
            when beginning_mrr > 0 and ending_mrr > 0 and ending_mrr < beginning_mrr then 'contraction'
            when beginning_mrr > 0 and ending_mrr = 0 then 'churn'
            when beginning_mrr > 0 and ending_mrr = beginning_mrr then 'retained'
            else 'inactive'
        end as movement_type
    from base
)

select
    mrr_waterfall_id,
    account_id,
    first_active_month,
    revenue_month,
    plan_tier,
    seats,
    cast(beginning_mrr as {{ dbt.type_float() }}) as beginning_mrr,
    cast(new_mrr as {{ dbt.type_float() }}) as new_mrr,
    cast(expansion_mrr as {{ dbt.type_float() }}) as expansion_mrr,
    cast(reactivation_mrr as {{ dbt.type_float() }}) as reactivation_mrr,
    cast(contraction_mrr as {{ dbt.type_float() }}) as contraction_mrr,
    cast(churned_mrr as {{ dbt.type_float() }}) as churned_mrr,
    cast(ending_mrr as {{ dbt.type_float() }}) as ending_mrr,
    movement_type
from classified
