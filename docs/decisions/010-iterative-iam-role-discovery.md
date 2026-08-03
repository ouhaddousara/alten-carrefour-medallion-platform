# ADR-010 : Découverte itérative des rôles IAM par essai-erreur

**Statut :** Résolu (pattern récurrent documenté)

## Contexte

Au fil du projet, le service account `data-platform-sa` — configuré dès la
Semaine 1 selon le principe du moindre privilège (ADR-002) — s'est révélé
insuffisant à trois reprises distinctes, chaque fois lors de l'introduction
d'un nouveau service GCP :

| Service | Rôle initial (Semaine 1) | Rôle manquant découvert | Quand |
|---|---|---|---|
| BigQuery | `bigquery.dataEditor` | `bigquery.jobUser` | Semaine 3, premier `dbt debug` |
| Dataproc | `dataproc.editor` | `dataproc.worker` | Semaine 2, premier `dataproc batches submit` |
| Composer | (aucun rôle Composer initial) | `composer.worker` + `roles/editor` sur le compte de service Compute par défaut | Semaine 4, première création d'environnement |

## Cause racine commune

Dans les trois cas, le rôle initialement accordé permet de **créer/gérer**
une ressource (soumettre un job, définir un environnement), mais un rôle
**distinct** est nécessaire pour que l'identité **exécute réellement le
travail** en tant qu'agent interne du service (exécuter les tâches internes
Dataproc, lancer des jobs BigQuery, faire tourner les pods GKE sous-jacents
à Composer). GCP sépare volontairement ces deux niveaux de permission par
service, pour un contrôle de sécurité plus fin — mais cette séparation
n'est pas toujours évidente à anticiper avant la première exécution réelle.

## Décision

Accepter cette découverte itérative comme un working pattern normal du
principe du moindre privilège, plutôt que de sur-provisionner des rôles
larges (`Editor`, `Owner`) par anticipation sur le service account
applicatif. Chaque nouveau rôle a été ajouté seulement au moment où le
besoin s'est concrètement manifesté, avec le message d'erreur GCP comme
guide précis (les messages d'erreur IAM de GCP identifient explicitement
le rôle manquant et le service account concerné).

## Conséquences

- Le service account `data-platform-sa` reste strictement scoped aux
  besoins réels du pipeline, sans permissions dormantes non utilisées.
- Ce pattern est à anticiper pour toute extension future du pipeline
  (nouveau service GCP ajouté) : prévoir un premier test d'intégration
  isolé avant un déploiement complet, plutôt que de supposer que les
  rôles existants suffiront.
- Liste consolidée des rôles finaux du service account, pour référence :
  `storage.admin`, `bigquery.dataEditor`, `bigquery.jobUser`,
  `dataproc.editor`, `dataproc.worker`, `pubsub.editor`, `run.invoker`,
  `composer.worker`.
