{{
  config(
    materialized = 'table',
    )
}}

SELECT
    id,
    name,
    email,
    address,
    created_at
FROM {{ ref('members_source') }}
WHERE created_at >= '2025-01-01 00:00:00'