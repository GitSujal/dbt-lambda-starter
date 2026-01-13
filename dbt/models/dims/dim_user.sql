{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    unique_key = ['user_id', 'user_role'],
    enabled = true
) }}

WITH dim_user AS (

    SELECT
        DISTINCT user_id,
        user_email,
        user_name,
        user_phone,
        user_role
    FROM
        {{ ref('current_memberships') }}
    WHERE
        user_id IS NOT NULL
)
SELECT
    *
FROM
    dim_user
