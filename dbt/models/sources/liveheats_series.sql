WITH series_source AS (
  SELECT
    *
  FROM
    {{ source(
      'liveheats',
      'series_raw'
    ) }}
),
renamed AS (
  SELECT
    {{ adapter.quote("id") }} AS id,
    {{ adapter.quote("name") }} AS name,
    split_part(name, ' ', 1) as year,
    {{ adapter.quote("childseries__id") }} AS series_id,
    {{ adapter.quote("childseries__name") }} AS series_name,
    {{ adapter.quote("source_file") }} AS source_file
  FROM
    series_source
)
SELECT
  *
FROM
  renamed
