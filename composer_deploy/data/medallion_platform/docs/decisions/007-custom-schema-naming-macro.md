# ADR-007 : Override du macro generate_schema_name pour cibler finances_objective_r

**Statut :** Adopté

## Contexte

Par convention, dbt préfixe automatiquement tout schéma/dataset BigQuery
personnalisé (défini via `config(schema=...)`) avec le schéma cible du
profil actif (`raw_bronze`), produisant par défaut un nom composé du type
`raw_bronze_finances_objective_r` — incompatible avec l'exigence de
M. Amara d'utiliser exactement `finances_objective_r`.

## Décision

Ajout d'un macro `generate_schema_name` personnalisé dans
`macros/generate_schema_name.sql`, remplaçant le comportement par défaut
pour utiliser le nom de schéma personnalisé tel quel, sans préfixation.

## Conséquences

- Tous les modèles Silver utilisant `config(schema='finances_objective_r')`
  écrivent exactement dans le dataset attendu.
- Point de vigilance : ce comportement global s'applique à tous les futurs
  modèles du projet définissant un schéma personnalisé — toute nouvelle
  couche (Gold, par exemple) devra explicitement définir son schéma cible
  pour éviter d'écrire par défaut dans le schéma du profil actif.
