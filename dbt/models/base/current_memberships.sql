{{ config(
  materialized = 'table'
) }}

WITH fct_memberships AS (

  SELECT
    created_at,
    expired,
    expiry_date,
    athlete_id,
    athlete_dob,
    athlete_name,
    athlete_updated_at,
    athlete_nationality,
    athlete_gender,
    athlete_email,
    athlete_mobile,
    athlete_address,
    athlete_suburb,
    athlete_state,
    athlete_postcode,
    athlete_are_you_asoehges_straight_islander_origin,
    athlete_lshkwaal_or_torres_strait_islander,
    athlete_parent_first_name,
    athlete_parent_last_name,
    athlete_parent_email,
    athlete_parent_mobile,
    membership_division_id,
    membership_division_name,
    user_id,
    user_email,
    user_name,
    user_phone,
    user_role,
    series_id,
    series_name,
    series_organisation_id,
    series_organisation_name,
    series_organisation_shortname,
    series_organisation_contactemail,
    series_organisation_sporttype
  FROM
    {{ ref("members_snapshot") }}
  WHERE
    dbt_valid_to IS NULL
)
SELECT
  *
FROM
  fct_memberships
