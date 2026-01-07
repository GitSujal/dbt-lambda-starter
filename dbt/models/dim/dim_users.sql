with dim_users as (
  select 
    distinct
    athlete__users__id as user_id,
    athlete__users__name as user_name,
    athlete__users__email as user_email,
    athlete__users__phone as user_phone,
    athlete__users__role as user_role
  from {{ source('athlete_source', 'athletes') }}
  where athlete__users__id is not null
)
select * from dim_users