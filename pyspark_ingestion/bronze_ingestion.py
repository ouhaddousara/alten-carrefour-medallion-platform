import argparse
import sys

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit
from pyspark.sql.types import StructType, StructField, StringType, DoubleType


def build_schema() -> StructType:
    
    return StructType([
        StructField("raw_month", StringType(), nullable=False),          
        StructField("raw_entity_org", StringType(), nullable=True),      
        StructField("raw_profit_center", StringType(), nullable=True),   
        StructField("raw_business_area", StringType(), nullable=True),
        StructField("raw_company", StringType(), nullable=True),         
        StructField("raw_account", StringType(), nullable=True),         
        StructField("raw_period_type", StringType(), nullable=True),     
        StructField("raw_phase", StringType(), nullable=True),           
        StructField("raw_value", DoubleType(), nullable=True),           
    ])


def parse_args():
    parser = argparse.ArgumentParser(description="Bronze layer ingestion job — P&L flow")
    parser.add_argument("--input_path", required=True,
                         help="Chemin GCS des fichiers .DEL, ex: gs://bucket/pending/*.DEL")
    parser.add_argument("--output_table", required=True,
                         help="Table BigQuery cible, format project.dataset.table")
    parser.add_argument("--temp_bucket", required=True,
                         help="Bucket GCS utilisé comme zone temporaire par le connecteur BigQuery")
    return parser.parse_args()


def main():
    args = parse_args()

    spark = (
        SparkSession.builder
        .appName("carrefour-bronze-pl-ingestion")
        .getOrCreate()
    )

    schema = build_schema()

    print(f"Lecture des fichiers depuis: {args.input_path}")
    df = (
        spark.read
        .option("header", "false")       
        .option("delimiter", "\t")       
        .option("encoding", "ISO-8859-1")  #
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

    df_enriched = (
        df
        .withColumn("_ingested_at", current_timestamp())
        .withColumn("_source_file", input_file_name())
        .withColumn("_ingestion_job", lit("bronze_pl_ingestion"))
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
