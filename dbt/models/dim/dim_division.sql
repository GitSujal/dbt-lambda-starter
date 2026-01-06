with dim_division as (
    select 
        distinct
        athlete__eventdivisions__division__id as division_id,
        athlete__eventdivisions__division__name as division_name
    from {{ source('athlete_source', 'athletes') }}
    where athlete__eventdivisions__division__id is not null
)
select * from dim_division