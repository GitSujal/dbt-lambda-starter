{{ config(
  materialized = 'table'
) }}

WITH fct_athletes AS (

  SELECT
    DISTINCT created_at,
    expired,
    expiry_date,
    athlete_id,
    user_id,
    membership_division_id,
    series_id,
    series_organisation_id
  FROM
    {{ ref('current_memberships') }}
  WHERE
    athlete_id IS NOT NULL
)
SELECT
  *
FROM
  fct_athletes
