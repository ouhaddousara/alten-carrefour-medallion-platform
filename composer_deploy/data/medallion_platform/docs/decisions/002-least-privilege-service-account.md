# ADR-002 : Permissions IAM à moindre privilège pour le service account

**Statut :** Adopté

## Contexte

Le pipeline (Cloud Run Function, jobs PySpark, futur DAG Airflow) doit
s'exécuter de façon automatisée, sans dépendre des identifiants personnels
d'un utilisateur humain.

## Décision

Création d'un service account dédié (`data-platform-sa`), avec attribution
progressive des rôles IAM strictement nécessaires à chaque étape du
pipeline, plutôt qu'un rôle large (`Owner` ou `Editor`) :

roles/storage.admin -> lecture/écriture GCS
roles/bigquery.dataEditor -> écriture des tables BigQuery
roles/bigquery.jobUser -> exécution de jobs de requête BigQuery
roles/dataproc.editor -> soumission de batches Dataproc
roles/dataproc.worker -> exécution interne des tâches par l'agent Dataproc
roles/pubsub.editor -> publication/écoute Pub/Sub
roles/run.invoker -> invocation de la Cloud Run Function


Les rôles `bigquery.jobUser` et `dataproc.worker` ont été ajoutés a
posteriori, suite à des erreurs de permissions rencontrées lors des tests
(voir historique de développement), révélant que `dataEditor` et
`dataproc.editor` seuls ne couvrent pas l'exécution effective des jobs.

## Conséquences

- En cas de fuite de la clé de service account, l'impact reste strictement
  limité aux actions nécessaires au pipeline.
- Nécessite une vigilance accrue lors de l'ajout de nouvelles
  fonctionnalités : chaque nouveau service GCP utilisé doit voir son rôle
  minimal identifié et ajouté explicitement, plutôt que d'élargir les
  permissions par défaut.
