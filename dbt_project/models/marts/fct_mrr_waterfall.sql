{{
    config(
        materialized='incremental',
        unique_key='mrr_waterfall_id',
        incremental_strategy='merge',
        on_schema_change='fail',
        partition_by={'field': 'revenue_month', 'data_type': 'date', 'granularity': 'month'},
        cluster_by=['account_id', 'plan_tier']
    )
}}

select
    m.mrr_waterfall_id,
    m.account_id,
    a.segment,
    a.acquisition_channel,
    m.first_active_month,
    m.revenue_month,
    m.plan_tier,
    m.seats,
    m.beginning_mrr,
    m.new_mrr,
    m.expansion_mrr,
    m.reactivation_mrr,
    m.contraction_mrr,
    m.churned_mrr,
    m.ending_mrr,
    m.movement_type
from {{ ref('int_mrr_movements') }} as m
inner join {{ ref('stg_accounts') }} as a
    on m.account_id = a.account_id
{% if is_incremental() %}
where m.revenue_month >= (select max(revenue_month) from {{ this }})
{% endif %}
