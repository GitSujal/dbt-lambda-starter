{{ 
    config(
        materialized='incremental',
        incremental_strategy='merge',
        on_schema_change='append_new_columns',
        unique_key=['athlete_id', 'user_id', 'series_id', 'division_id', 'eventdivision_id'],
        table_type='iceberg',
        format='parquet',
        write_compression='snappy'
    ) 
}}

with dim_athletes as (
    select
        distinct
        createdat as created_at,
        expired as expired,
        expirydate as expiry_date,
        athlete__id as athlete_id,
        athlete__dob as dob,
        athlete__name as name,
        athlete__updatedat as updated_at,
        gender,
        athlete__properties___3__address as address,
        athlete__properties___4__suburb as suburb,
        athlete__properties___5__state as state,
        athlete__properties___6__postcode as postcode,
        athlete__properties___7__are_lshkwaal_or_torres_strait_islander as are_lshkwaal_or_torres_strait_islander,
        athlete__users__id as user_id,
        series__id as series_id,
        athlete__eventdivisions__division__id as division_id,
        athlete__eventdivisions__id as eventdivision_id
    from {{ ref('membership_data_current') }}
    where athlete__id is not null
    {% if is_incremental() %}
    and createdat >= coalesce((select max(created_at) from {{ this }}), '1900-01-01')
    {% endif %}
)

select * from dim_athletes
