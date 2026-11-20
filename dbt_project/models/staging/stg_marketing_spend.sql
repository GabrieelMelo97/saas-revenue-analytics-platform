select
    cast(spend_id as {{ dbt.type_string() }}) as spend_id,
    cast(spend_month as date) as spend_month,
    cast(segment as {{ dbt.type_string() }}) as segment,
    cast(acquisition_channel as {{ dbt.type_string() }}) as acquisition_channel,
    cast(spend_amount as {{ dbt.type_float() }}) as spend_amount
from {{ source('raw_saas', 'marketing_spend') }}
