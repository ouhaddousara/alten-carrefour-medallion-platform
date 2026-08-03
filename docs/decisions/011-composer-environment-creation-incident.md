# ADR-011 : Incident de création de l'environnement Cloud Composer

**Statut :** Résolu

## Contexte

La création du premier environnement Cloud Composer
(`carrefour-composer-env`) a échoué à deux reprises consécutives avant
d'aboutir, chaque échec révélant une étape de configuration préalable non
anticipée — un pattern déjà rencontré lors de la configuration initiale du
projet en Semaine 1 (billing, APIs), mais spécifique cette fois à Composer.

## Échecs rencontrés, dans l'ordre

**1. Permissions manquantes du Service Agent Composer**

FAILED_PRECONDITION: Cloud Composer Service Agent service account is
missing required permissions: iam.serviceAccounts.getIamPolicy,
iam.serviceAccounts.setIamPolicy

Résolu par l'attribution du rôle `roles/composer.ServiceAgentV2Ext` au
compte de service interne `service-503680028075@cloudcomposer-accounts
.iam.gserviceaccount.com` — une étape d'auto-configuration requise lors
de la toute première création d'un environnement Composer sur un projet.

**2. API Kubernetes Engine non activée**

FAILED_PRECONDITION: Please enable all APIs Cloud Composer depends on.
List of APIs: [container.googleapis.com]

Résolu par `gcloud services enable container.googleapis.com` — Composer 2
repose sur GKE en interne pour exécuter les workers Airflow, dépendance
non explicitement documentée dans la commande de création elle-même.

**3. Échec de santé des pods GKE (state: ERROR)**

Some of the GKE pods failed to become healthy.
Missing role: roles/composer.worker (data-platform-sa)
Missing role: roles/editor (compute default service account)

Résolu par l'attribution de `roles/composer.worker` au service account
applicatif, et `roles/editor` au compte de service Compute Engine par
défaut (utilisé implicitement par les nœuds GKE sous-jacents à
l'environnement) — voir ADR-010 pour le pattern général.

## Décision

Documenter cette séquence complète comme référence pour toute future
recréation de l'environnement (le projet prévoit de supprimer
l'environnement après validation pour maîtriser les coûts, donc une
recréation future est probable). Les 4 prérequis identifiés doivent être
vérifiés avant toute nouvelle tentative :
1. `roles/composer.ServiceAgentV2Ext` sur le Service Agent Composer
2. API `container.googleapis.com` activée
3. `roles/composer.worker` sur le service account applicatif
4. `roles/editor` sur le compte de service Compute Engine par défaut

## Conséquences

- Le processus de recréation de l'environnement (si nécessaire après
  suppression pour maîtrise des coûts) est documenté et reproductible en
  une seule tentative, sans repasser par ces trois cycles d'échec.
- Ce type d'incident illustre que même une infrastructure managée
  ("serverless") comme Cloud Composer nécessite une configuration IAM
  explicite lors de sa première utilisation sur un projet — la
  simplicité opérationnelle du service ne dispense pas d'une
  compréhension de son modèle de permissions sous-jacent.

## Décision finale

Après 7 tentatives de création et l'épuisement des pistes de diagnostic
accessibles via la CLI standard (IAM, APIs, réseau, VPC peering, logs
`k8s_cluster`), la décision a été prise d'arrêter les tentatives répétées
de création de l'environnement Cloud Composer, plutôt que de continuer à
consommer du temps et du budget cloud sans nouvelle piste de diagnostic.

## Stratégie de compensation adoptée

Le DAG (`carrefour_pl_medallion_pipeline.py`) reste développé et versionné.
Pour démontrer la validité de sa logique métier malgré l'indisponibilité de
l'environnement d'orchestration, les deux tâches du DAG ont été exécutées
manuellement, dans le même ordre et avec les mêmes commandes que celles
qu'Airflow aurait automatiquement déclenchées :

1. `ingest_bronze_pyspark` — soumission manuelle du même batch Dataproc
   Serverless que `DataprocCreateBatchOperator` aurait exécuté
2. `run_dbt_silver_and_gold` — exécution manuelle de `dbt run && dbt test`,
   identique à ce que `BashOperator` aurait exécuté

Cette approche valide la **logique** du pipeline (l'enchaînement correct
des étapes et leur succès individuel), sans valider l'**orchestration
automatisée** elle-même, qui reste bloquée par la limitation
d'infrastructure documentée ci-dessus.

## Statut final

**Non résolu** au niveau infrastructure Cloud Composer — escaladé à
M. Amara. **Compensé fonctionnellement** par une exécution manuelle
équivalente, documentée comme preuve de la validité du pipeline.
