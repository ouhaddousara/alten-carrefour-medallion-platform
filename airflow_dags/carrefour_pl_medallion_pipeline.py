"""
DAG d'orchestration du pipeline Medallion — indicateurs Profit & Loss Objective.
Correspond au job de production "bgl-finances-profit-loss-indicators-month".

Séquence :
  1. Ingestion Bronze via PySpark sur Dataproc Serverless
  2. Transformation Silver + agrégation Gold via dbt (venv local au worker),
     suivi des tests qualité
"""
from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.google.cloud.operators.dataproc import DataprocCreateBatchOperator

PROJECT_ID = "black-octagon-502709-e2"
REGION = "europe-west1"
RAW_ZONE_BUCKET = "carrefour-raw-zone-black-octagon"
SERVICE_ACCOUNT = f"data-platform-sa@{PROJECT_ID}.iam.gserviceaccount.com"

DBT_PROJECT_DIR = "/home/airflow/gcs/data/medallion_platform/medallion_platform"
DBT_VENV_DIR = "/tmp/dbt_venv"

BATCH_ID = "bronze-ingestion-{{ ds_nodash }}-{{ ts_nodash[-6:] }}"

BATCH_CONFIG = {
    "pyspark_batch": {
        "main_python_file_uri": f"gs://{RAW_ZONE_BUCKET}/scripts/bronze_ingestion.py",
        "args": [
            f"--input_path=gs://{RAW_ZONE_BUCKET}/pending/*.csv",
            f"--output_table={PROJECT_ID}.raw_bronze.bronze_staging",
            f"--temp_bucket={RAW_ZONE_BUCKET}",
        ],
    },
    "runtime_config": {
        "version": "2.2",
    },
    "environment_config": {
        "execution_config": {
            "service_account": SERVICE_ACCOUNT,
        }
    },
}

default_args = {
    "owner": "sara",
    "retries": 1,
}

DBT_BASH_COMMAND = f"""
set -e
rm -rf {DBT_VENV_DIR}
python3 -m venv {DBT_VENV_DIR}
{DBT_VENV_DIR}/bin/pip install --quiet --upgrade pip
{DBT_VENV_DIR}/bin/pip install --quiet dbt-core==1.7.14 dbt-bigquery==1.7.9
{DBT_VENV_DIR}/bin/dbt deps --project-dir {DBT_PROJECT_DIR}
{DBT_VENV_DIR}/bin/dbt run --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}
{DBT_VENV_DIR}/bin/dbt test --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}
"""

with DAG(
    dag_id="carrefour_pl_medallion_pipeline",
    description="Pipeline Bronze -> Silver -> Gold pour les indicateurs Profit & Loss Objective (Budget)",
    default_args=default_args,
    schedule_interval="@daily",
    start_date=datetime(2026, 7, 29),
    catchup=False,
    tags=["carrefour", "medallion", "finance"],
) as dag:

    ingest_bronze = DataprocCreateBatchOperator(
        task_id="ingest_bronze_pyspark",
        project_id=PROJECT_ID,
        region=REGION,
        batch=BATCH_CONFIG,
        batch_id=BATCH_ID,
    )

    run_dbt_transform = BashOperator(
        task_id="run_dbt_silver_and_gold",
        bash_command=DBT_BASH_COMMAND,
    )

    ingest_bronze >> run_dbt_transform
