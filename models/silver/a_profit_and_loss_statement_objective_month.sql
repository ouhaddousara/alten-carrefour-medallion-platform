{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=[
            'monthStartDate', 'costCenterKey', 'profitCenterKey',
            'businessAreaKey', 'companyKey', 'accountingAccountKey',
            'phaseCode', 'auditTrackingCode'
        ],
        schema='finances_objective_r',
        alias='a_profit_and_loss_statement_objective_month',
        partition_by={'field': 'monthStartDate', 'data_type': 'date'},
        cluster_by=['companyKey', 'profitCenterKey']
    )
}}

with staged as (

    select * from {{ ref('stg_bronze_pl') }}

    {% if is_incremental() %}
    where _ingested_at > (select coalesce(max(_ingested_at), timestamp('1970-01-01')) from {{ this }})
    {% endif %}

),

filtered as (

    select *
    from staged

    where monthStartDate is not null
      and costCenterKey is not null
      and profitCenterKey is not null
      and businessAreaKey is not null
      and companyKey is not null
      and accountingAccountKey is not null
      and phaseCode is not null
      and auditTrackingCode is not null

),

deduplicated as (

    select *
    from filtered
    qualify row_number() over (
        partition by
            monthStartDate, costCenterKey, profitCenterKey, businessAreaKey,
            companyKey, accountingAccountKey, phaseCode, auditTrackingCode
        order by _ingested_at desc
    ) = 1

)

select
    monthStartDate,
    costCenterKey,
    profitCenterKey,
    businessAreaKey,
    companyKey,
    accountingAccountKey,
    periodTypeCode,
    phaseCode,
    auditTrackingCode,
    profitAndLossObjectiveIndicatorValue,
    _ingested_at,
    _source_file,
    current_timestamp() as _silver_processed_at

from deduplicated
