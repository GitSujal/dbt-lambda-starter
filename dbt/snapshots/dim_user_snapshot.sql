{% snapshot dim_user_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with users_source as (
    select 
      *
      from {{ ref("dim_user") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['user_id', 'user_role']) }} as snapshot_pk,
    * 
from users_source

{% endsnapshot %}
