select
    safe.parse_date('%Y%m', raw_month) as monthStartDate,
    raw_month as _raw_month,

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
    _source_file

from {{ source('raw_bronze', 'bronze_staging') }}
