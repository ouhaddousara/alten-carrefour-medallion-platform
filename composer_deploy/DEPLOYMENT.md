# Procédure de déploiement Composer

## 1. Créer l'environnement (une fois le billing confirmé)
gcloud composer environments create carrefour-composer-env \
  --location=europe-west1 \
  --image-version=composer-2-airflow-2 \
  --service-account=data-platform-sa@black-octagon-502709-e2.iam.gserviceaccount.com

## 2. Installer les packages PyPI nécessaires
gcloud composer environments update carrefour-composer-env \
  --location=europe-west1 \
  --update-pypi-packages-from-file=requirements-composer.txt

## 3. Récupérer le bucket GCS de l'environnement
gcloud composer environments describe carrefour-composer-env \
  --location=europe-west1 \
  --format="value(config.dagGcsPrefix)"

## 4. Uploader le DAG et le projet dbt
gsutil -m cp dags/*.py gs://BUCKET_COMPOSER/dags/
gsutil -m cp -r data/medallion_platform gs://BUCKET_COMPOSER/data/

## 5. Déclencher une exécution manuelle de test
gcloud composer environments run carrefour-composer-env \
  --location=europe-west1 \
  dags trigger -- carrefour_pl_medallion_pipeline

## 6. Une fois validé, supprimer l'environnement pour arrêter les coûts
gcloud composer environments delete carrefour-composer-env --location=europe-west1
