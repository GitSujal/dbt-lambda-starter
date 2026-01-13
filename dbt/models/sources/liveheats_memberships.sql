{{ config(
  materialized = 'table'
) }}

WITH memberships_source AS (

  SELECT
    *
  FROM
    {{ source(
      'liveheats',
      'memberships_raw'
    ) }}
),
renamed AS (
  SELECT
    {{ adapter.quote("createdat") }} AS created_at,
    {{ adapter.quote("expired") }} AS expired,
    {{ adapter.quote("expirydate") }} AS expiry_date,
    {{ adapter.quote("athlete__id") }} AS athlete_id,
    {{ adapter.quote("athlete__dob") }} AS athlete_dob,
    {{ adapter.quote("athlete__name") }} AS athlete_name,
    {{ adapter.quote("athlete__updatedat") }} AS athlete_updated_at,
    {{ adapter.quote("athlete__properties__nationality") }} AS athlete_nationality,
    COALESCE({{ adapter.quote("athlete__properties__genderx") }}, {{ adapter.quote("athlete__properties___1__gender") }}, {{ adapter.quote("athlete__properties__gender") }}) AS athlete_gender,
    {{ adapter.quote("athlete__properties__emailx") }} AS athlete_email,
    {{ adapter.quote("athlete__properties__mobilex") }} AS athlete_mobile,
    COALESCE({{ adapter.quote("athlete__properties__addressx") }}, {{ adapter.quote("athlete__properties___3__address") }}) AS athlete_address,
    COALESCE({{ adapter.quote("athlete__properties__townx") }}, {{ adapter.quote("athlete__properties___4__suburb") }}) AS athlete_suburb,
    COALESCE({{ adapter.quote("athlete__properties__postcodex") }}, {{ adapter.quote("athlete__properties___6__postcode") }}) AS athlete_postcode,
    COALESCE({{ adapter.quote("athlete__properties__statex") }}, {{ adapter.quote("athlete__properties___5__state") }}, {{ adapter.quote("athlete__properties__state") }}) AS athlete_state,
    {{ adapter.quote("athlete__properties__are_you_asoehges_straight_islander_originx") }} AS "athlete_are_you_asoehges_straight_islander_origin",
    {{ adapter.quote("athlete__properties___7__are_lshkwaal_or_torres_strait_islander") }} AS "athlete_lshkwaal_or_torres_strait_islander",
    {{ adapter.quote("athlete__properties__parent_first_namex") }} AS athlete_parent_first_name,
    {{ adapter.quote("athlete__properties__parent_last_namex") }} AS athlete_parent_last_name,
    {{ adapter.quote("athlete__properties__parent_emailx") }} AS athlete_parent_email,
    {{ adapter.quote("athlete__properties__parent_mobilex") }} AS athlete_parent_mobile,
    {{ adapter.quote("athlete__users__id") }} AS user_id,
    {{ adapter.quote("athlete__users__email") }} AS user_email,
    {{ adapter.quote("athlete__users__name") }} AS user_name,
    {{ adapter.quote("athlete__users__phone") }} AS user_phone,
    {{ adapter.quote("athlete__users__role") }} AS user_role,
    {{ adapter.quote("series__id") }} AS series_id,
    {{ adapter.quote("series__name") }} AS series_name,
    {{ adapter.quote("series__organisation__id") }} AS series_organisation_id,
    {{ adapter.quote("series__organisation__name") }} AS series_organisation_name,
    {{ adapter.quote("series__organisation__shortname") }} AS series_organisation_shortname,
    {{ adapter.quote("series__organisation__contactemail") }} AS series_organisation_contactemail,
    {{ adapter.quote("series__organisation__sporttype") }} AS series_organisation_sporttype,
    {{ adapter.quote("series__membershipdivisions__id") }} AS membership_division_id,
    {{ adapter.quote("series__membershipdivisions__name") }} AS membership_division_name,
    {{ adapter.quote("loaded_at") }} AS loaded_at,
    {{ adapter.quote("source_file") }} AS source_file
  FROM
    memberships_source
)
SELECT
  *
FROM
  renamed
WHERE
  loaded_at = (
    SELECT
      MAX(loaded_at)
    FROM
      renamed
  )
