{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_pl_top_cost_centers'
    )
}}

select
    accountingAccountKey,
    companyKey,
    sum(profitAndLossObjectiveIndicatorValue) as total_value,
    sum(abs(profitAndLossObjectiveIndicatorValue)) as total_absolute_value,
    count(*) as nb_lignes,
    rank() over (order by sum(abs(profitAndLossObjectiveIndicatorValue)) desc) as rang

from {{ ref('a_profit_and_loss_statement_objective_month') }}
group by accountingAccountKey, companyKey
qualify rang <= 20
order by rang
