select
    concat(
        cast(account_id as {{ dbt.type_string() }}),
        '_',
        cast(billing_month as {{ dbt.type_string() }})
    ) as subscription_month_sk,
    cast(subscription_id as {{ dbt.type_string() }}) as subscription_id,
    cast(account_id as {{ dbt.type_string() }}) as account_id,
    cast(plan_tier as {{ dbt.type_string() }}) as plan_tier,
    cast(status as {{ dbt.type_string() }}) as subscription_status,
    cast(mrr_amount as {{ dbt.type_float() }}) as mrr_amount,
    cast(seats as {{ dbt.type_int() }}) as seats,
    cast(billing_month as date) as revenue_month,
    cast(subscription_start_date as date) as subscription_start_date,
    cast(updated_at as {{ dbt.type_timestamp() }}) as updated_at
from {{ source('raw_saas', 'subscriptions') }}
