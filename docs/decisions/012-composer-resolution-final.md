# ADR-012 : Résolution finale du blocage Cloud Composer

**Date :** 2026-08-04
**Statut :** Résolu
**Supersede :** ADR-011

## Contexte

Suite à l'échec documenté dans l'ADR-011 (7 tentatives, hypothèse de
cause racine : quota SSD régional), M. Amara a repris l'investigation
avec un accès Owner complémentaire et identifié une cause différente.

## Root cause réelle, identifiée par M. Amara

Sur Composer 2/3, GKE Autopilot nécessite que le **compte de service
Compute Engine par défaut**
(`503680028075-compute@developer.gserviceaccount.com`) possède
explicitement le rôle `roles/composer.worker`, et que le Service Agent
Composer possède `roles/composer.ServiceAgentV2Ext` — **en plus** des
rôles déjà attribués au service account applicatif custom
(`data-platform-sa`).

Cette distinction n'avait pas été couverte par les 7 tentatives
précédentes : celles-ci corrigeaient systématiquement les permissions du
service account custom spécifié pour l'environnement, sans anticiper
qu'Autopilot sollicite également le compte de service Compute par
défaut en interne pour certaines opérations d'infrastructure, même
lorsqu'un service account custom est explicitement fourni.

## Divergence avec l'hypothèse de l'ADR-011

L'ADR-011 concluait à un quota SSD insuffisant (`SSD_TOTAL_GB` observé à
200/250 Go pendant une tentative active). Cette observation reste
factuellement exacte, mais s'interprète a posteriori comme un
**symptôme corrélé** plutôt que la cause racine : chaque tentative de
provisioning consommait du quota SSD (disques de boot des nœuds
Autopilot, invisibles depuis le projet) avant d'échouer sur le vrai
blocage IAM, donnant l'illusion d'une saturation de quota alors que le
mécanisme sous-jacent était un échec de permission empêchant les pods de
finaliser leur démarrage.

## Actions de résolution appliquées (par M. Amara)

```bash
gcloud services enable composer.googleapis.com container.googleapis.com \
  artifactregistry.googleapis.com cloudbuild.googleapis.com

gcloud projects add-iam-policy-binding black-octagon-502709-e2 \
  --member="serviceAccount:503680028075-compute@developer.gserviceaccount.com" \
  --role="roles/composer.worker"

gcloud projects add-iam-policy-binding black-octagon-502709-e2 \
  --member="serviceAccount:service-503680028075@cloudcomposer-accounts.iam.gserviceaccount.com" \
  --role="roles/composer.ServiceAgentV2Ext"
```

Suivi d'un nettoyage de l'environnement corrompu et d'une recréation
propre.

## Résultat

gcloud composer environments describe carrefour-composer-env
--location=europe-west1 --format="value(state)"
→ RUNNING


## Décision

Reprise du déploiement réel du DAG (`carrefour_pl_medallion_pipeline.py`)
sur l'environnement désormais fonctionnel, remplaçant la stratégie de
compensation manuelle (ADR-011) par une validation en conditions réelles
via Cloud Composer.

## Conséquences

- La stratégie de compensation manuelle (exécution directe des 2 tâches
  hors Airflow) devient superflue pour la suite du projet, mais reste
  documentée dans l'ADR-011 comme preuve de la démarche de diagnostic et
  de la validité fonctionnelle du pipeline pendant la période de
  blocage.
- Ce cas illustre une limite de l'investigation en solo sur un projet où
  les permissions IAM peuvent être réparties entre plusieurs comptes de
  service dont l'un (custom) est visible et corrigé, tandis qu'un autre
  (compte par défaut, sollicité implicitement par l'infrastructure
  managée) reste hors du radar sans un second regard ou une
  documentation Google plus explicite sur cette dépendance interne.
- Point méthodologique pour un futur projet : sur GKE Autopilot/Composer
  2+, vérifier systématiquement les permissions du compte de service
  Compute Engine par défaut du projet, même quand un service account
  custom est explicitement fourni à la ressource managée.

## Confirmation finale du déploiement — 04 août 2026

Après résolution de la root cause (rôles IAM manquants sur les comptes de
service Compute et Composer, corrigés par M. Amara), le déploiement du DAG
a nécessité une série d'ajustements complémentaires, chacun révélé par
l'exécution réelle en environnement Composer :

1. **Venv sur GCSFuse trop lent** → déplacé vers stockage local du worker
   (`/tmp`), l'écriture de milliers de petits fichiers Python sur
   stockage monté GCSFuse étant intrinsèquement lente
2. **Zone GCE temporairement indisponible** (`europe-west1-d`) → résolu
   par un simple nouveau déclenchement (aléa transitoire d'infrastructure)
3. **Structure de dossier imbriquée** lors de l'upload du projet dbt via
   `storage data import` → chemin ajusté dans le DAG
4. **`packages.yml` mal formé** pour dbt 1.7 (format de version
   incompatible) → corrigé vers la syntaxe liste
5. **`package-lock.yml` figé par une version dbt différente** (1.11 en
   local vs 1.7 sur Composer) → retiré du contrôle de version,
   régénéré à chaque exécution
6. **Syntaxe de test dbt incompatible** (`arguments:` introduit dans
   dbt 1.9+, absent en 1.7) → syntaxe de test revertie vers le format
   compatible dbt 1.7

## Résultat final

Task 1 (ingest_bronze_pyspark) : SUCCESS
Task 2 (run_dbt_silver_and_gold) : SUCCESS
dbt run : PASS=9 WARN=0 ERROR=0 (92.72s)
dbt test : PASS=19 WARN=0 ERROR=0 (13.30s)


**Statut final : Résolu et validé en conditions réelles.** Le pipeline
Bronze → Silver → Gold s'exécute désormais de façon entièrement
automatisée via Cloud Composer, conformément à l'exigence initiale de la
spécification du stage.

## Conséquence méthodologique notable

Ce déploiement illustre qu'un environnement d'orchestration managé
fonctionnel (`state: RUNNING`) n'est qu'une précondition, pas une
garantie d'exécution correcte : six problèmes distincts et indépendants
ont dû être résolus après la résolution de l'incident d'infrastructure
initial, chacun spécifique à l'écart entre l'environnement de
développement local (dbt 1.11) et l'environnement d'exécution managé
(dbt 1.7.14 imposé par Composer). Ceci souligne l'importance de tester
un pipeline dans son environnement cible réel plutôt que de supposer
qu'un succès en local se traduit automatiquement en succès en
production.
