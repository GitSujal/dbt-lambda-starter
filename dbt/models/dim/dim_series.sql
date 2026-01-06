with dim_series as (
  select 
    distinct
    series__id as series_id,
    series__name as series_name
  from {{ source('athlete_source', 'athletes') }}
  where series__id is not null
)
select * from dim_series