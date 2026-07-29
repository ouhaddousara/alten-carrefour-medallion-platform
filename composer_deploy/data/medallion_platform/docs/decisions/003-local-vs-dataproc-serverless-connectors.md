# ADR-003 : Alignement des versions et gestion des connecteurs entre exécution locale et Dataproc Serverless

**Statut :** Adopté

## Contexte

Le script d'ingestion PySpark a été testé en local avant tout déploiement
cloud, afin de valider la logique métier à moindre coût et avec un
débogage plus rapide.

## Problèmes rencontrés

1. **Version PySpark locale (4.2.0) incompatible** avec tous les runtimes
   Dataproc Serverless disponibles (max Spark 4.0.0 sur le runtime 3.0).
   Correction : alignement sur PySpark 3.5.1, correspondant au runtime
   Dataproc 2.2 LTS retenu.
2. **Connecteurs manquants en local** (GCS et BigQuery), nécessitant leur
   fourniture manuelle via `--jars` et une configuration d'authentification
   explicite — inutile sur Dataproc Serverless, où GCS est nativement
   intégré.
3. **Conflit de classes sur Dataproc Serverless** (`not a subtype:
   BigQueryRelationProvider`) causé par la fourniture explicite du
   connecteur BigQuery via `--jars`, alors que celui-ci est déjà intégré
   nativement dans les runtimes Dataproc 2.1+.

## Décision

- Fixer la version PySpark locale sur 3.5.1 pour correspondre exactement
  au runtime Dataproc 2.2 utilisé en production.
- Fournir explicitement les connecteurs GCS et BigQuery en local
  uniquement (jamais sur Dataproc Serverless).
- Ne jamais spécifier `--jars` pour le connecteur BigQuery lors d'une
  soumission de batch Dataproc Serverless (runtime 2.1+).

## Conséquences

Le test local reste un environnement volontairement différent de la
production sur le plan de la configuration technique (connecteurs,
authentification), mais garantit un comportement Spark identique grâce à
l'alignement strict des versions.
