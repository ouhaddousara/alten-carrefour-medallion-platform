# Procédure de déploiement Composer

**Sources de vérité (ne jamais dupliquer) :**
- DAG : `airflow_dags/carrefour_pl_medallion_pipeline.py`
- Projet dbt : racine du repo (`dbt_project.yml`, `models/`, `macros/`, `packages.yml`)

Les commandes ci-dessous régénèrent temporairement une copie locale de
déploiement (non versionnée, voir `.gitignore`), l'uploadent sur GCS, puis
peuvent être supprimées.

## 1. Créer l'environnement (une fois le billing confirmé)
gcloud composer environments create carrefour-composer-env \
  --location=europe-west1 \
  --image-version=composer-2-airflow-2 \
  --service-account=data-platform-sa@black-octagon-502709-e2.iam.gserviceaccount.com

## 2. Installer les packages PyPI nécessaires
gcloud composer environments update carrefour-composer-env \
  --location=europe-west1 \
  --update-pypi-packages-from-file=composer_deploy/requirements-composer.txt

## 3. Récupérer le bucket GCS de l'environnement
gcloud composer environments describe carrefour-composer-env \
  --location=europe-west1 \
  --format="value(config.dagGcsPrefix)"

## 4. Régénérer localement une copie de déploiement du projet dbt (temporaire, non versionnée)
mkdir -p composer_deploy/data/medallion_platform
rsync -av \
  --exclude='.venv' --exclude='.git' --exclude='logs' --exclude='target' \
  --exclude='dbt_packages' --exclude='sample_data' --exclude='composer_deploy' \
  --exclude='airflow_dags' --exclude='pyspark_ingestion' --exclude='cloud_run_function' \
  ./ composer_deploy/data/medallion_platform/

## 5. Uploader le DAG et le projet dbt régénéré
gsutil -m cp airflow_dags/carrefour_pl_medallion_pipeline.py gs://BUCKET_COMPOSER/dags/
gsutil -m cp -r composer_deploy/data/medallion_platform gs://BUCKET_COMPOSER/data/

## 6. Nettoyer la copie locale temporaire
rm -rf composer_deploy/data/

## 7. Déclencher une exécution manuelle de test
gcloud composer environments run carrefour-composer-env \
  --location=europe-west1 \
  dags trigger -- carrefour_pl_medallion_pipeline

## 8. Une fois validé, supprimer l'environnement pour arrêter les coûts
gcloud composer environments delete carrefour-composer-env --location=europe-west1
