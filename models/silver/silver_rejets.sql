{{
    config(
        materialized='incremental',
        schema='finances_objective_r',
        alias='silver_rejets'
    )
}}

with staged as (

    select * from {{ ref('stg_bronze_pl') }}

    {% if is_incremental() %}
    where _ingested_at > (select coalesce(max(_ingested_at), timestamp('1970-01-01')) from {{ this }})
    {% endif %}

),

rejected as (

    select
        *,
        array_to_string(
            array_concat(
                case when monthStartDate is null then ['monthStartDate manquant/format invalide'] else [] end,
                case when costCenterKey is null then ['costCenterKey manquant'] else [] end,
                case when profitCenterKey is null then ['profitCenterKey manquant'] else [] end,
                case when businessAreaKey is null then ['businessAreaKey manquant'] else [] end,
                case when companyKey is null then ['companyKey manquant'] else [] end,
                case when accountingAccountKey is null then ['accountingAccountKey manquant'] else [] end,
                case when phaseCode is null then ['phaseCode manquant'] else [] end,
                case when auditTrackingCode is null then ['auditTrackingCode manquant'] else [] end
            ),
            ', '
        ) as rejection_reason,
        current_timestamp() as _rejected_at

    from staged
    where monthStartDate is null
       or costCenterKey is null
       or profitCenterKey is null
       or businessAreaKey is null
       or companyKey is null
       or accountingAccountKey is null
       or phaseCode is null
       or auditTrackingCode is null

)

select * from rejected
