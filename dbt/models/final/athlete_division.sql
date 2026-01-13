{{ config(
    materialized = 'table',
) }}

SELECT
    DISTINCT dim_ath.*,
    dim_division.*
FROM
    {{ ref('fct_athlete') }} fct_ath
    LEFT JOIN {{ ref('dim_athlete') }} dim_ath
    ON fct_ath.athlete_id = dim_ath.athlete_id
    LEFT JOIN {{ ref('dim_division') }} dim_division
    ON fct_ath.membership_division_id = dim_division.division_id
