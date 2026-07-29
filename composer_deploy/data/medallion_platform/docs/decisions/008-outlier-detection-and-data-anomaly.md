# ADR-008 : Détection de valeurs aberrantes et anomalie de données source identifiée

**Statut :** Adopté (mécanisme de détection) / Signalé (anomalie source, en attente de retour Carrefour)

## Contexte

Lors de la vérification du modèle `gold_pl_top_cost_centers` (classement des
comptes comptables par poids budgétaire), des valeurs extrêmement
improbables ont été observées : un compte affichant un total de l'ordre de
1,88 × 10^15 (quadrillion), sans commune mesure avec l'échelle financière
attendue (valeurs typiques de l'ordre du million à la dizaine de
millions d'euros).

## Investigation

Une requête d'isolement par compte et société a révélé que cette valeur
provenait d'une **ligne unique** dans le fichier source `pl_202602.csv`
(mois de mars 2026, centre de coût `X160AC0493`, société `1386`), et non
d'un pattern répété. Une seconde ligne, quasiment opposée en valeur
(-1,879 × 10^15 sur le compte `9614260000`, contre +1,879 × 10^15 sur le
compte `9614360000`), a été identifiée dans le même fichier source, même
mois, même centre de coût — suggérant une paire d'écritures comptables
(possiblement débit/crédit) affectées par une même anomalie d'extraction
côté système source (EPM Board), plutôt qu'une erreur du pipeline
d'ingestion.

## Décision

1. **Mécanisme de détection généralisé** : ajout d'un modèle
   `gold_pl_anomalies`, identifiant toute ligne dont la valeur absolue
   dépasse 10 écarts-types au-dessus de la moyenne des valeurs absolues de
   la table Silver — une méthode statistique simple, sans seuil arbitraire
   codé en dur, permettant de détecter automatiquement ce type d'anomalie
   sur de futurs chargements.
2. **Aucune correction ou suppression appliquée** aux données Silver ou
   Gold : les deux lignes concernées restent en l'état, la responsabilité
   de validation/correction des données sources relevant du système
   d'origine (EPM Board), pas du pipeline d'ingestion.
3. Signalement de l'anomalie à M. Amara pour vérification côté source.

## Conséquences

- Le modèle `gold_pl_top_cost_centers` reste techniquement correct
  (reflète fidèlement les données source), mais ses deux premiers rangs
  sont actuellement non représentatifs de la réalité métier tant que
  l'anomalie source n'est pas corrigée.
- Le modèle `gold_profit_and_loss_objective_summary` (agrégats globaux)
  n'est que marginalement affecté, les deux valeurs aberrantes se
  compensant presque exactement lors de la sommation.
- Ce mécanisme de détection constitue une première étape de contrôle
  qualité au niveau Gold, complémentaire aux tests `not_null` et
  d'unicité déjà appliqués en Silver — utile à documenter comme practice
  de validation de plausibilité métier, distincte de la validation de
  complétude technique.

## Mise à jour

M. Amara a confirmé qu'il s'agit d'une anomalie isolée (2 lignes) et a
demandé leur exclusion. La logique de détection statistique (10
écarts-types), initialement conçue comme un modèle de monitoring
(`gold_pl_anomalies`), a été intégrée directement dans le modèle Silver
comme filtre d'exclusion, avec routage vers `silver_rejets` pour
conserver la traçabilité — plutôt qu'une suppression directe en base,
qui aurait rompu l'auditabilité du pipeline.

**Statut : Résolu.**
