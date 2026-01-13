{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    unique_key = ['athlete_id'],
    enabled = true
) }}

WITH dim_athlete AS (

    SELECT
        DISTINCT athlete_id,
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
        athlete_parent_mobile
    FROM
        {{ ref('current_memberships') }}
    WHERE
        athlete_id IS NOT NULL
    {% if is_incremental() %}
    AND athlete_updated_at >= COALESCE(
        (
            SELECT
                MAX(athlete_updated_at)
            FROM
                {{ this }}
        ),
        '1900-01-01'
    )
    {% endif %}
)
SELECT
    *
FROM
    dim_athlete
