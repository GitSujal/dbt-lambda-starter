{% snapshot fct_athlete_snapshot %}

{{
    config(
      target_schema='dev-snsw-dataplatform',
      unique_key='snapshot_pk',
      strategy='check',
      check_cols='all'
    )
}}

with fct_athlete_source as (
    select 
      *
      from {{ ref("fct_athlete") }}
)

select 
    {{ dbt_utils.generate_surrogate_key(['athlete_id', 'user_id', 'membership_division_id', 'series_id', 'series_organisation_id']) }} as snapshot_pk,
    * 
from fct_athlete_source

{% endsnapshot %}
