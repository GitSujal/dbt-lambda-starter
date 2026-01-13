{{ config(
    materialized = 'table',
) }}

SELECT
    fct_ath.created_at,
    fct_ath.expired,
    fct_ath.expiry_date,
    dim_ath.*,
    dim_user.*,
    dim_division.*,
    dim_series.*,
    dim_org.*
FROM
    {{ ref('fct_athlete') }} fct_ath
    LEFT JOIN {{ ref('dim_athlete') }} dim_ath
    ON fct_ath.athlete_id = dim_ath.athlete_id
    LEFT JOIN {{ ref('dim_user') }} dim_user
    ON fct_ath.user_id = dim_user.user_id
    LEFT JOIN {{ ref('dim_division') }} dim_division
    ON fct_ath.membership_division_id = dim_division.division_id
    LEFT JOIN {{ ref('dim_series') }} dim_series
    ON fct_ath.series_id = dim_series.series_id
    LEFT JOIN {{ ref('dim_organisation') }} dim_org
    ON fct_ath.series_organisation_id :: INTEGER = dim_org.organisation_id
