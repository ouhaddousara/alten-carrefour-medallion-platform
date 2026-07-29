{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_pl_profit_center_breakdown'
    )
}}

select
    monthStartDate,
    companyKey,
    profitCenterKey,
    count(*) as nb_lignes,
    sum(profitAndLossObjectiveIndicatorValue) as total_value,
    countif(costCenterKey = 'NCC') as nb_lignes_ncc,
    round(safe_divide(countif(costCenterKey = 'NCC'), count(*)) * 100, 1) as pct_ncc

from {{ ref('a_profit_and_loss_statement_objective_month') }}
group by monthStartDate, companyKey, profitCenterKey
order by monthStartDate, companyKey, profitCenterKey
