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

stats as (

    select
        avg(abs(profitAndLossObjectiveIndicatorValue)) as avg_abs_value,
        stddev(abs(profitAndLossObjectiveIndicatorValue)) as stddev_abs_value
    from staged
    where profitAndLossObjectiveIndicatorValue is not null

),

rejected as (

    select
        s.*,
        array_to_string(
            array_concat(
                case when s.monthStartDate is null then ['monthStartDate manquant/format invalide'] else [] end,
                case when s.costCenterKey is null then ['costCenterKey manquant'] else [] end,
                case when s.profitCenterKey is null then ['profitCenterKey manquant'] else [] end,
                case when s.businessAreaKey is null then ['businessAreaKey manquant'] else [] end,
                case when s.companyKey is null then ['companyKey manquant'] else [] end,
                case when s.accountingAccountKey is null then ['accountingAccountKey manquant'] else [] end,
                case when s.phaseCode is null then ['phaseCode manquant'] else [] end,
                case when s.auditTrackingCode is null then ['auditTrackingCode manquant'] else [] end,
                case
                    when abs(s.profitAndLossObjectiveIndicatorValue) > stats.avg_abs_value + (10 * stats.stddev_abs_value)
                    then ['valeur aberrante (>10 écarts-types), validation M. Amara']
                    else []
                end
            ),
            ', '
        ) as rejection_reason,
        current_timestamp() as _rejected_at

    from staged s
    cross join stats

    where s.monthStartDate is null
       or s.costCenterKey is null
       or s.profitCenterKey is null
       or s.businessAreaKey is null
       or s.companyKey is null
       or s.accountingAccountKey is null
       or s.phaseCode is null
       or s.auditTrackingCode is null
       or abs(s.profitAndLossObjectiveIndicatorValue) > stats.avg_abs_value + (10 * stats.stddev_abs_value)

)

select * from rejected
