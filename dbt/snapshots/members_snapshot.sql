{% snapshot members_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key=['athlete__id', 'athlete__users__id', 'series__id', 'athlete__eventdivisions__division__id', 'athlete__eventdivisions__id'],
      strategy='check',
      check_cols='all',
      hard_deletes="new_record",
    )
}}

with athlete_source as (
    select 
        *
    from {{ source('athlete_source', 'athletes') }}
)

select * from athlete_source

{% endsnapshot %}