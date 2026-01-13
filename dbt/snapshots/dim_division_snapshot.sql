{% snapshot dim_division_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with division_source as (
    select 
      *
      from {{ ref("dim_division") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['division_id']) }} as snapshot_pk,
    * 
from division_source

{% endsnapshot %}