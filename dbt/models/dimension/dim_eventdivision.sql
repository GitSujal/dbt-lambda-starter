{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        on_schema_change='append_new_columns',
        unique_key=['eventdivision_id'],
        table_type='iceberg',
        format='parquet',
        write_compression='snappy'
    )
}}

with dim_eventdivision as (
    select
        distinct
        athlete__eventdivisions__id as eventdivision_id,
        athlete__eventdivisions__division__id as division_id
    from {{ ref('membership_data_current') }}
    where athlete__eventdivisions__id is not null
    and athlete__eventdivisions__division__id is not null
)

select * from dim_eventdivision