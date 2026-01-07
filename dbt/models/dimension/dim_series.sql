{{ 
    config(
        materialized='incremental',
        incremental_strategy='merge',
        on_schema_change='append_new_columns',
        unique_key=['series_id'],
        table_type='iceberg',
        format='parquet',
        write_compression='snappy'
    ) 
}}

with dim_series as (
    select 
        distinct
        series__id as series_id,
        series__name as series_name
    from {{ ref('membership_data_current') }}
    where series__id is not null
)

select * from dim_series
