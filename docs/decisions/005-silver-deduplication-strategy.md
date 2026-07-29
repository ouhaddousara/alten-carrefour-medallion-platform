# ADR-002 : Stratégie de déduplication de la couche Silver

**Statut :** Adopté

## Contexte

Le modèle Silver `a_profit_and_loss_statement_objective_month` utilise une
clé primaire composite de 8 champs (monthStartDate, costCenterKey,
profitCenterKey, businessAreaKey, companyKey, accountingAccountKey,
phaseCode, auditTrackingCode), telle que définie dans la spécification
Carrefour (`Données Source : Budget`).

Après le premier chargement complet (`dbt run`), les 9 tests de qualité dbt
ont été exécutés. Les 8 tests `not_null` sont passés avec succès, mais le
test `dbt_utils.unique_combination_of_columns` a échoué avec
**5 312 502 violations** sur 15 865 021 lignes.

## Investigation

Une requête d'investigation groupant les lignes par clé composite a révélé
que les doublons provenaient d'une caractéristique connue des données
source : chaque fichier mensuel extrait du système EPM Board contient le
**Budget complet de l'année entière** (12 mois), et non uniquement les
données du mois indiqué dans le nom du fichier.

En chargeant 4 fichiers d'extraction différents (pl_202602, pl_202603,
pl_202605, pl_202606), les lignes correspondant aux mois communs aux 4
fichiers ont été insérées jusqu'à 4 fois — soit avec des valeurs
identiques (Budget non révisé entre deux extractions), soit avec des
valeurs différentes (Budget révisé entre deux extractions).

**Exemple observé (valeur révisée) :**

Clé identique, valeurs : [-5265.196, 1.0, 1.0, 1.0]

Ce cas confirme que la donnée la plus récemment ingérée (`_ingested_at`
le plus élevé) représente la version à jour du Budget pour cette ligne.

## Cause racine

La stratégie `merge` de dbt protège contre la duplication **entre deux
exécutions successives** du pipeline, mais ne déduplique pas les lignes
**au sein d'un même chargement** lorsque la table est créée pour la
première fois (`CREATE TABLE`, pas `MERGE`).

## Décision

Ajout d'une étape de déduplication explicite dans le modèle Silver, en
amont de l'écriture finale, à l'aide de `QUALIFY ROW_NUMBER() OVER (...)`
partitionné par la clé composite et trié par `_ingested_at` décroissant —
ne conservant que la ligne la plus récemment ingérée pour chaque
combinaison de clé.

```sql
qualify row_number() over (
    partition by
        monthStartDate, costCenterKey, profitCenterKey, businessAreaKey,
        companyKey, accountingAccountKey, phaseCode, auditTrackingCode
    order by _ingested_at desc
) = 1
```

## Conséquences

- Volume de la table Silver réduit de 15 865 021 à 6 137 101 lignes
  (~61 % de réduction) après reconstruction complète (`--full-refresh`).
- Les 9 tests de qualité dbt passent désormais avec succès.
- Cette logique garantit qu'en cas de révision d'un Budget entre deux
  extractions, seule la valeur la plus récente est conservée en Silver —
  cohérent avec le mode d'insertion "Insert Update" spécifié par
  M. Amara.
- Point de vigilance pour la suite : si de futurs chargements incrémentaux
  contiennent eux-mêmes des doublons internes (plusieurs lignes du même
  fichier, même `_ingested_at`), la déduplication par `_ingested_at` seul
  ne suffira pas à départager — à surveiller lors des prochains
  chargements.
