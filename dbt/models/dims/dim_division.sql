{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    unique_key = ['division_id'],
    enabled = true
) }}

WITH dim_division AS (

    SELECT
        DISTINCT membership_division_id AS division_id,
        membership_division_name AS division_name
    FROM
        {{ ref('current_memberships') }}
    WHERE
        membership_division_id IS NOT NULL
)
SELECT
    *
FROM
    dim_division
