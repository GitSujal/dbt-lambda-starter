with dim_series_organizaion as (
  select 
    distinct
    series__id as series_id,
    series__organisation__name as organization_name,
    series__organisation__shortname as organization_shortname,
    series__organisation__contactemail as organization_email,
    series__organisation__sporttype as organization_sporttype
  from {{ source('athlete_source', 'athletes') }}
  where series__id is not null
)
select * from dim_series_organizaion