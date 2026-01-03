{{
    config(
        materialized='view'
    )
}}

with snapshot_data as (
    select * from {{ ref('members_snapshot') }}
)

select
    member_id,
    name,
    dob,
    email,
    address,
    dbt_valid_from as start_date,
    dbt_valid_to as end_date,
    case 
        when dbt_valid_to is null then true 
        else false 
    end as current_flag
from snapshot_data
