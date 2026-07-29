{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_pl_month_over_month_variance'
    )
}}

with monthly as (

    select
        monthStartDate,
        companyKey,
        businessAreaKey,
        sum(profitAndLossObjectiveIndicatorValue) as total_value

    from {{ ref('a_profit_and_loss_statement_objective_month') }}
    group by monthStartDate, companyKey, businessAreaKey

),

with_previous as (

    select
        monthStartDate,
        companyKey,
        businessAreaKey,
        total_value,
        lag(total_value) over (
            partition by companyKey, businessAreaKey
            order by monthStartDate
        ) as previous_month_value

    from monthly

)

select
    monthStartDate,
    companyKey,
    businessAreaKey,
    total_value,
    previous_month_value,
    total_value - previous_month_value as variance_amount,
    safe_divide(total_value - previous_month_value, abs(previous_month_value)) as variance_pct

from with_previous
order by monthStartDate, companyKey
