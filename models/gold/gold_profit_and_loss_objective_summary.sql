{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_profit_and_loss_objective_summary'
    )
}}

select
    monthStartDate,
    companyKey,
    businessAreaKey,
    phaseCode,
    count(*) as nb_lignes,
    sum(profitAndLossObjectiveIndicatorValue) as total_indicator_value,
    avg(profitAndLossObjectiveIndicatorValue) as avg_indicator_value

from {{ ref('a_profit_and_loss_statement_objective_month') }}

group by
    monthStartDate,
    companyKey,
    businessAreaKey,
    phaseCode

order by
    monthStartDate,
    companyKey
