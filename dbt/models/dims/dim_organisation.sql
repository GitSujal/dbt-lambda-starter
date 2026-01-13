{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    unique_key = ['organisation_id'],
    enabled = true
) }}

WITH dim_organisation AS (

    SELECT
        DISTINCT organisation_id,
        organisation_name,
        organisation_shortname,
        organisation_contactemail,
        organisation_sporttype,
        organisation_series
    FROM
        {{ ref('liveheats_organisation') }}
    WHERE
        organisation_id IS NOT NULL
)
SELECT
    *
FROM
    dim_organisation
