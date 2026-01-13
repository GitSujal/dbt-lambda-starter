{% snapshot dim_organisation_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with organisation_source as (
    select 
      *
      from {{ ref("dim_organisation") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['organisation_id']) }} as snapshot_pk,
    * 
from organisation_source

{% endsnapshot %}
