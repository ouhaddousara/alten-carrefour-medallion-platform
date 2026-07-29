# ADR-004 : Conception du schéma Bronze — fidélité à la source et typage prudent

**Date :** 2026-07-23
**Statut :** Adopté

## Contexte

Au moment de la conception du schéma Bronze, le mapping métier cible
(noms de colonnes Silver, règles de transformation) n'était pas encore
confirmé par M. Amara.

## Décision

1. **Noms de colonnes Bronze reflétant la structure source** (`raw_month`,
   `raw_entity_org`, etc.), et non les noms cibles métier
   (`monthStartDate`, `costCenterKey`...). Le renommage et les
   transformations métier sont réservés exclusivement à la couche Silver.
2. **Typage systématique en `STRING`** pour toute colonne représentant un
   identifiant ou un code, même à apparence numérique (ex : `raw_business_area`
   = `"0635"`), afin de préserver les zéros non significatifs et
   d'empêcher tout calcul numérique dénué de sens métier. Seule la colonne
   de valeur financière (`raw_value`) est typée en `FLOAT`.

## Conséquences

- Le schéma Bronze n'a nécessité aucune modification lors de la réception
  ultérieure de la spécification métier confirmée — seule la couche
  Silver a dû être adaptée.
- Découplage complet entre l'étape d'ingestion technique et l'évolution
  des règles métier, réduisant le risque de retouche en cascade.
