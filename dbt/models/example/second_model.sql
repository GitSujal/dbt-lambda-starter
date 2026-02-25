{{
  config(
    materialized = 'view',
    )
}}

select *
from {{ ref('first_model') }}
where email like '%@example.com'