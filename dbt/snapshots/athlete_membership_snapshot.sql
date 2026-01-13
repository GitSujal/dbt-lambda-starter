{% snapshot athlete_series_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with athlete_series_source as (
    select 
      *
      from {{ ref("athlete_membership") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['athlete_id', 'series_id']) }} as snapshot_pk,
    * 
from athlete_series_source

{% endsnapshot %}
