select
    cast(invoice_id as {{ dbt.type_string() }}) as invoice_id,
    cast(subscription_id as {{ dbt.type_string() }}) as subscription_id,
    cast(account_id as {{ dbt.type_string() }}) as account_id,
    cast(billing_month as date) as billing_month,
    cast(amount_due as {{ dbt.type_float() }}) as amount_due,
    cast(amount_paid as {{ dbt.type_float() }}) as amount_paid,
    cast(invoice_status as {{ dbt.type_string() }}) as invoice_status,
    cast(issued_at as {{ dbt.type_timestamp() }}) as issued_at
from {{ source('raw_saas', 'invoices') }}
