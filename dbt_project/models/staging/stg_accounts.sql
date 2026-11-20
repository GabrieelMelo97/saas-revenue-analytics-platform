select
    cast(account_id as {{ dbt.type_string() }}) as account_id,
    cast(company_name as {{ dbt.type_string() }}) as company_name,
    cast(segment as {{ dbt.type_string() }}) as segment,
    cast(industry as {{ dbt.type_string() }}) as industry,
    cast(country as {{ dbt.type_string() }}) as country,
    cast(acquisition_channel as {{ dbt.type_string() }}) as acquisition_channel,
    cast(created_at as date) as signup_month
from {{ source('raw_saas', 'accounts') }}
