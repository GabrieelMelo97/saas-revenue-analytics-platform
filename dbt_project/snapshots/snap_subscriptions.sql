{% snapshot snap_subscriptions %}

{{
    config(
        unique_key='subscription_month_sk',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

-- SCD Type 2 snapshot preserving historical plan_tier, seats, and MRR changes
select
    concat(account_id, '_', cast(billing_month as {{ dbt.type_string() }})) as subscription_month_sk,
    subscription_id,
    account_id,
    plan_tier,
    status,
    cast(mrr_amount as {{ dbt.type_float() }}) as mrr_amount,
    cast(seats as {{ dbt.type_int() }}) as seats,
    cast(billing_month as date) as billing_month,
    cast(subscription_start_date as date) as subscription_start_date,
    cast(updated_at as {{ dbt.type_timestamp() }}) as updated_at
from {{ source('raw_saas', 'subscriptions') }}

{% endsnapshot %}
