{% snapshot members_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='member_id',
      strategy='check',
      check_cols=['name', 'dob', 'email', 'address'],
      invalidate_hard_deletes=True,
    )
}}

select 
    member_id,
    name,
    dob,
    email,
    address
from {{ ref('members_source') }}

{% endsnapshot %}
