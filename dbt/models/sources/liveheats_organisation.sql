WITH source AS (
  SELECT
    *
  FROM
    {{ source(
      'liveheats',
      'organisation_raw'
    ) }}
),
organisation_details AS (
  SELECT
    {{ adapter.quote("id") }} AS organisation_id,
    {{ adapter.quote("name") }} AS organisation_name,
    {{ adapter.quote("shortname") }} AS organisation_shortname,
    {{ adapter.quote("contactemail") }} AS organisation_contactemail,
    {{ adapter.quote("sporttype") }} AS organisation_sporttype,
    {{ adapter.quote("series") }} AS organisation_series,
    {{ adapter.quote("source_file") }}
  FROM
    source
  LIMIT
    1
), federated_organisations AS (
  SELECT
    {{ adapter.quote("federatedorganisations__id") }} AS organisation_id,
    {{ adapter.quote("federatedorganisations__name") }} AS organisation_name,
    {{ adapter.quote("federatedorganisations__shortname") }} AS organisation_shortname,
    {{ adapter.quote("federatedorganisations__contactemail") }} AS organisation_contactemail,
    {{ adapter.quote("federatedorganisations__sporttype") }} AS organisation_sporttype,
    {{ adapter.quote("federatedorganisations__series") }} AS organisation_series,
    {{ adapter.quote("source_file") }}
  FROM
    source
  WHERE
    {{ adapter.quote("federatedorganisations__id") }} IS NOT NULL
),
organisation_source AS (
  SELECT
    *
  FROM
    organisation_details
  UNION ALL
  SELECT
    *
  FROM
    federated_organisations
)
SELECT
  *
FROM
  organisation_source
