{% snapshot dim_series_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with series_source as (
    select 
      *
      from {{ ref("dim_series") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['series_id']) }} as snapshot_pk,
    * 
from series_source

{% endsnapshot %}
