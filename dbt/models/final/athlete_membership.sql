{{ config(
    materialized = 'table',
) }}

SELECT
    DISTINCT fct_ath.expired,
    fct_ath.expiry_date,
    dim_ath.*,
    dim_series.*,
    dim_org.*
FROM
    {{ ref('fct_athlete') }} fct_ath
    LEFT JOIN {{ ref('dim_athlete') }} dim_ath
    ON fct_ath.athlete_id = dim_ath.athlete_id
    LEFT JOIN {{ ref('dim_series') }} dim_series
    ON fct_ath.series_id = dim_series.series_id
    LEFT JOIN {{ ref('dim_organisation') }} dim_org
    ON fct_ath.series_organisation_id::INTEGER = dim_org.organisation_id
