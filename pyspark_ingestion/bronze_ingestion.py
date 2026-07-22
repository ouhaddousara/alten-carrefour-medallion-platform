"""
Job PySpark d'ingestion Bronze.
Lit les fichiers CSV validés depuis raw-zone/pending, applique un schéma
strict, ajoute des métadonnées de traçabilité, et écrit le résultat dans
BigQuery (raw_bronze.bronze_staging).
"""
import argparse
import sys

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType


def build_schema() -> StructType:
    """Schéma strict imposé sur les fichiers CSV entrants."""
    return StructType([
        StructField("id", IntegerType(), nullable=False),
        StructField("name", StringType(), nullable=True),
        StructField("value", DoubleType(), nullable=True),
    ])


def parse_args():
    parser = argparse.ArgumentParser(description="Bronze layer ingestion job")
    parser.add_argument("--input_path", required=True,
                         help="Chemin GCS des fichiers CSV, ex: gs://bucket/pending/*.csv")
    parser.add_argument("--output_table", required=True,
                         help="Table BigQuery cible, format project.dataset.table")
    parser.add_argument("--temp_bucket", required=True,
                         help="Bucket GCS utilisé comme zone temporaire par le connecteur BigQuery")
    return parser.parse_args()


def main():
    args = parse_args()

    spark = (
        SparkSession.builder
        .appName("carrefour-bronze-ingestion")
        .getOrCreate()
    )

    schema = build_schema()

    print(f"Lecture des fichiers CSV depuis: {args.input_path}")
    df = (
        spark.read
        .option("header", "true")
        .option("delimiter", ",")
        .option("mode", "PERMISSIVE")
        .schema(schema)
        .csv(args.input_path)
    )

    row_count = df.count()
    print(f"Nombre de lignes lues: {row_count}")

    if row_count == 0:
        print("Aucune donnée à ingérer. Fin du job.")
        spark.stop()
        sys.exit(0)

    # Métadonnées de traçabilité — pratique standard en ingestion Bronze
    df_enriched = (
        df
        .withColumn("_ingested_at", current_timestamp())
        .withColumn("_source_file", input_file_name())
        .withColumn("_ingestion_job", lit("bronze_ingestion"))
    )

    print(f"Écriture vers BigQuery: {args.output_table}")
    (
        df_enriched.write
        .format("bigquery")
        .option("table", args.output_table)
        .option("temporaryGcsBucket", args.temp_bucket)
        .mode("append")
        .save()
    )

    print("Ingestion terminée avec succès.")
    spark.stop()


if __name__ == "__main__":
    main()
