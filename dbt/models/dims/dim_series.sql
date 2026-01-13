{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    unique_key = ['series_id'],
    enabled = true
) }}

WITH dim_series AS (

    SELECT
        DISTINCT id,
        name,
        year,
        series_id,
        series_name
    FROM
        {{ ref('liveheats_series') }}
    WHERE
        id IS NOT NULL
)
SELECT
    *
FROM
    dim_series
