{{
    config(
        materialized='table',
        schema='mart_gold',
        alias='gold_pipeline_quality_kpi'
    )
}}

with bronze_count as (
    select count(*) as nb_lignes
    from {{ source('raw_bronze', 'bronze_staging') }}
),

silver_count as (
    select count(*) as nb_lignes
    from {{ ref('a_profit_and_loss_statement_objective_month') }}
),

rejets_count as (
    select count(*) as nb_lignes
    from {{ ref('silver_rejets') }}
)

select
    (select nb_lignes from bronze_count) as total_bronze,
    (select nb_lignes from silver_count) as total_silver_valide,
    (select nb_lignes from rejets_count) as total_rejets,
    round(
        safe_divide(
            (select nb_lignes from rejets_count),
            (select nb_lignes from bronze_count)
        ) * 100, 2
    ) as taux_rejet_pct,
    round(
        safe_divide(
            (select nb_lignes from bronze_count) - (select nb_lignes from silver_count),
            (select nb_lignes from bronze_count)
        ) * 100, 2
    ) as taux_deduplication_pct,
    current_timestamp() as _computed_at
