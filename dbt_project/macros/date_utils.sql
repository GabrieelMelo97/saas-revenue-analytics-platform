{% macro month_diff(start_date_col, end_date_col) %}
    {% if target.type == 'bigquery' %}
        date_diff({{ end_date_col }}, {{ start_date_col }}, month)
    {% else %}
        cast(
            (extract(year from {{ end_date_col }}) - extract(year from {{ start_date_col }})) * 12
            + (extract(month from {{ end_date_col }}) - extract(month from {{ start_date_col }}))
            as integer
        )
    {% endif %}
{% endmacro %}
