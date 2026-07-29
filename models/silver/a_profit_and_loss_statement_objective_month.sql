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

with bronze as (

    select
        raw_month,
        raw_entity_org,
        raw_profit_center,
        raw_business_area,
        raw_company,
        raw_account,
        raw_period_type,
        raw_phase,
        raw_audit_tracking,
        raw_value,
        _ingested_at,
        _source_file
    from {{ source('raw_bronze', 'bronze_staging') }}

    {% if is_incremental() %}
    where _ingested_at > (select coalesce(max(_ingested_at), timestamp('1970-01-01')) from {{ this }})
    {% endif %}

),

transformed as (

    select
        -- Mois au format YYYYMM -> premier jour du mois
        parse_date('%Y%m', raw_month) as monthStartDate,

        -- Règle NCC : si centre de coût = centre de profit, remplacer par "NCC"
        case
            when raw_entity_org = raw_profit_center then 'NCC'
            else raw_entity_org
        end as costCenterKey,

        raw_profit_center as profitCenterKey,
        raw_business_area as businessAreaKey,
        raw_company as companyKey,
        raw_account as accountingAccountKey,
        raw_period_type as periodTypeCode,
        raw_phase as phaseCode,
        raw_audit_tracking as auditTrackingCode,
        raw_value as profitAndLossObjectiveIndicatorValue,

        _ingested_at,
        _source_file,
        current_timestamp() as _silver_processed_at

    from bronze

)

select * from transformed
