# ADR-009 : Incident d'isolation du schéma CI et correction

**Statut :** Résolu

## Contexte

Suite à la mise en place du pipeline CI/CD (GitHub Actions), le premier
run de `dbt run --empty` a été exécuté avec succès (`PASS=9`). Une
vérification post-hoc du dataset `ci_validation` censé isoler les runs CI
n'a montré qu'une seule table (`stg_bronze_pl`), révélant que les 8
autres modèles (Silver, silver_rejets, 6 modèles Gold) avaient été écrits
directement dans les datasets de **production**
(`finances_objective_r`, `mart_gold`).

## Cause racine

Le macro `generate_schema_name` (introduit en Semaine 3, ADR-007) honore
systématiquement le paramètre `schema=` défini explicitement dans la
configuration de chaque modèle, sans tenir compte du `target` dbt actif.
Le mécanisme d'isolation prévu pour la CI (profil pointant vers le
dataset `ci_validation`) n'affectait donc que les modèles sans schéma
personnalisé (uniquement la vue de staging).

## Impact

- Les modèles Silver (`materialized='incremental'`, stratégie `merge`)
  ont exécuté un `MERGE` avec une source vide contre les tables de
  production — sans impact constaté sur le volume de données (tests de
  qualité post-incident : PASS=9/9).
- Les modèles Gold (`materialized='table'`) ont été **entièrement
  recréés vides**, écrasant les données de production existantes. Aucune
  perte définitive : les modèles ont été régénérés avec succès via un
  nouveau `dbt run` sur les données réelles.

## Décision

Modification du macro `generate_schema_name` pour vérifier explicitement
le nom du `target` actif : lorsque `target.name == 'ci'`, tous les
modèles sont forcés vers le schéma du profil (`ci_validation`),
indépendamment de leur configuration `schema=` individuelle.

## Conséquences

- Aucune écriture future du pipeline CI ne peut atteindre les datasets
  de production, quelle que soit la configuration de schéma des modèles
  ajoutés ultérieurement.
- Point de vigilance méthodologique : ce type d'incident souligne
  l'importance de vérifier le contenu réel des ressources créées après
  un premier déploiement CI/CD, plutôt que de se fier uniquement au
  statut "succès" retourné par l'outil — un run peut réussir techniquement
  tout en produisant un effet de bord non désiré.
