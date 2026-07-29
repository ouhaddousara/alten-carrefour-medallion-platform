# ADR-006 : Modèle staging partagé entre Silver et silver_rejets

**Statut :** Adopté

## Contexte

La couche Silver nécessite deux sorties distinctes à partir des mêmes
données Bronze transformées : une table de données valides
(`a_profit_and_loss_statement_objective_month`) et une table de rejets
(`silver_rejets`) pour les lignes à clé primaire incomplète.

## Problème évité

Sans modèle intermédiaire, la logique de transformation (conversion de
date, règle NCC, renommage des colonnes) aurait dû être dupliquée dans les
deux modèles finaux — toute évolution future de cette logique aurait
nécessité une modification synchronisée à deux endroits, avec risque de
divergence.

## Décision

Introduction d'un modèle dbt intermédiaire (`stg_bronze_pl`), matérialisé
en vue, qui effectue uniquement la transformation sans aucun filtrage. Les
deux modèles finaux (Silver et rejets) référencent ce modèle via `ref()`
et appliquent chacun leur propre condition de filtrage (clé complète vs
incomplète).

## Conséquences

- La logique de transformation n'existe qu'à un seul endroit du code.
- Toute évolution des règles métier (ex. modification de la règle NCC) ne
  nécessite qu'une seule modification, automatiquement répercutée sur les
  deux sorties.
