{{
    config(
        materialized='table',
        table_type='iceberg',
        format='parquet',
        write_compression='snappy'
    )
}}

with membership_data_current as (
    select * from {{ ref('members_snapshot') }}
)

select
    createdat,
    expired,
    expirydate,
    athlete__id,
    athlete__dob,
    athlete__name,
    athlete__updatedat,
    coalesce(athlete__properties___1__gender, athlete__properties__gender) as gender,
    athlete__properties___3__address,
    athlete__properties___4__suburb,
    athlete__properties___5__state,
    athlete__properties___6__postcode,
    athlete__properties___7__are_lshkwaal_or_torres_strait_islander,
    athlete__eventdivisions__id,
    athlete__eventdivisions__division__id,
    athlete__eventdivisions__division__name,
    athlete__users__id,
    athlete__users__email,
    athlete__users__name,
    athlete__users__phone,
    athlete__users__role,
    series__id,
    series__name,
    series__organisation__name,
    series__organisation__shortname,
    series__organisation__contactemail,
    series__organisation__sporttype,
    source_file,
    dbt_valid_from as start_date,
    dbt_valid_to as end_date,
    dbt_is_deleted as is_deleted,
    case 
        when dbt_valid_to is null and dbt_is_deleted = 'False' then true 
        else false 
    end as current_flag
from membership_data_current
