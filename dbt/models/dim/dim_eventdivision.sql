with dim_eventdivision as (
    select 
        distinct
        athlete__eventdivisions__id as eventdivision_id,
        athlete__eventdivisions__division__id as division_id
    from {{ source('athlete_source', 'athletes') }}
    where athlete__eventdivisions__id is not null
    and athlete__eventdivisions__division__id is not null
)
select * from dim_eventdivision