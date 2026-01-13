{{ config(
  materialized = 'table'
) }}

WITH test_fct_athletes AS (

  SELECT
    DISTINCT cm.created_at,
    cm.expired,
    cm.expiry_date,
    cm.athlete_id,
    cm.user_id,
    cm.membership_division_id,
    cm.series_id,
    cm.series_organisation_id AS organisation_id
  FROM
    {{ ref('current_memberships') }} cm
    JOIN {{ ref('dim_athlete') }} da
    ON cm.athlete_id = da.athlete_id
    JOIN {{ ref('dim_user') }} du
    ON cm.user_id = du.user_id
    JOIN {{ ref('dim_division') }} dd
    ON cm.membership_division_id = dd.division_id
    JOIN {{ ref('dim_organisation') }} d
    ON cm.series_organisation_id :: INTEGER = d.organisation_id
  WHERE
    cm.athlete_id IS NOT NULL
)
SELECT
  *
FROM
  test_fct_athletes
