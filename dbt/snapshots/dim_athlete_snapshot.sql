{% snapshot dim_athlete_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with athlete_source as (
    select 
      *
      from {{ ref("dim_athlete") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['athlete_id']) }} as snapshot_pk,
    * 
from athlete_source

{% endsnapshot %}