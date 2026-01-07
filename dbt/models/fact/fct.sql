{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    on_schema_change='append_new_columns',
    unique_key=['athlete_id', 'user_id', 'series_id', 'division_id', 'eventdivision_id'],
    table_type='iceberg',
    format='parquet',
    write_compression='snappy'
) }}

with fct_athletes as (
  select
    da.athlete_id,
    du.user_id,
    ds.series_id,
    dd.division_id,
    de.eventdivision_id
  from {{ ref('dim_athletes') }} da
  left join {{ ref('dim_users') }} du on da.user_id = du.user_id
  left join {{ ref('dim_series') }} ds on da.series_id = ds.series_id
  left join {{ ref('dim_division') }} dd on da.division_id = dd.division_id
  left join {{ ref('dim_eventdivision') }} de on da.eventdivision_id = de.eventdivision_id
  where da.athlete_id is not null
  {% if is_incremental() %}
    and da.created_at >= coalesce((select max(created_at) from {{ this }}), '1900-01-01')
  {% endif %}
)

select * from fct_athletes