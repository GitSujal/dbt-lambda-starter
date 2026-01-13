{% snapshot athlete_division_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with athlete_division_source as (
    select 
      *
      from {{ ref("athlete_division") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['athlete_id', 'division_id']) }} as snapshot_pk,
    * 
from athlete_division_source

{% endsnapshot %}
