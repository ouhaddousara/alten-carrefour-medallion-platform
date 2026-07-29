{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_pl_anomalies'
    )
}}

with stats as (

    select
        avg(abs(profitAndLossObjectiveIndicatorValue)) as avg_abs_value,
        stddev(abs(profitAndLossObjectiveIndicatorValue)) as stddev_abs_value

    from {{ ref('a_profit_and_loss_statement_objective_month') }}

)

select
    s.monthStartDate,
    s.companyKey,
    s.costCenterKey,
    s.profitCenterKey,
    s.accountingAccountKey,
    s.profitAndLossObjectiveIndicatorValue,
    s._source_file

from {{ ref('a_profit_and_loss_statement_objective_month') }} s
cross join stats

where abs(s.profitAndLossObjectiveIndicatorValue) > stats.avg_abs_value + (10 * stats.stddev_abs_value)

order by abs(s.profitAndLossObjectiveIndicatorValue) desc
