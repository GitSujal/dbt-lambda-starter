with fct_athletes as (
  select
    dim_athletes.*,
    dim_users.user_name,
    dim_users.user_email,
    dim_users.user_phone,
    dim_users.user_role,
    dim_series.series_name,
    dim_series_organization.organization_name,
    dim_series_organization.organization_shortname,
    dim_series_organization.organization_email,
    dim_series_organization.organization_sporttype,
    dim_division.division_name
  from {{ ref('dim_athletes') }}
  full outer join {{ ref('dim_users') }} on dim_athletes.user_id = dim_users.user_id
  full outer join {{ ref('dim_series') }} on dim_athletes.series_id = dim_series.series_id
  full outer join {{ ref('dim_series_organization') }} on dim_series.series_id = dim_series_organization.series_id
  full outer join {{ ref('dim_division') }} on dim_athletes.division_id = dim_division.division_id
  where dim_athletes.athlete_id is not null
)

select * from fct_athletes