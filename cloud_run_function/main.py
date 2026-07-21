import base64
import json
import logging
import os

import functions_framework
from google.cloud import storage

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

RAW_ZONE_BUCKET = os.environ.get("RAW_ZONE_BUCKET", "carrefour-raw-zone-black-octagon")
ALLOWED_EXTENSION = ".csv"
PENDING_PREFIX = "pending/"

storage_client = storage.Client()


@functions_framework.cloud_event
def route_file(cloud_event):
    """Déclenchée par une notification Pub/Sub émise par GCS (OBJECT_FINALIZE).
    Valide l'extension du fichier déposé dans landing-zone et le déplace vers
    raw-zone/pending/ s'il est valide. Les fichiers invalides sont laissés en
    place et journalisés.
    """
    message = cloud_event.data.get("message", {})
    attributes = message.get("attributes", {})

    bucket_name = attributes.get("bucketId")
    file_name = attributes.get("objectId")

    # Repli : décoder le corps du message si les attributs sont absents
    if not bucket_name or not file_name:
        data_b64 = message.get("data")
        if not data_b64:
            logger.error("Message Pub/Sub sans données exploitables: %s", message)
            return
        try:
            payload = json.loads(base64.b64decode(data_b64).decode("utf-8"))
            bucket_name = payload.get("bucket")
            file_name = payload.get("name")
        except Exception as exc:
            logger.error("Échec du décodage du message Pub/Sub: %s", exc)
            return

    if not bucket_name or not file_name:
        logger.error("bucket_name ou file_name manquant après parsing.")
        return

    logger.info("Événement reçu pour gs://%s/%s", bucket_name, file_name)

    # Ignore les objets placeholder de dossiers (ex: .keep)
    if file_name.endswith("/") or file_name.endswith(".keep"):
        logger.info("Objet ignoré (non applicable): %s", file_name)
        return

    if not file_name.lower().endswith(ALLOWED_EXTENSION):
        logger.warning(
            "Fichier rejeté '%s': extension invalide (attendu %s). "
            "Fichier laissé dans landing-zone.",
            file_name, ALLOWED_EXTENSION
        )
        return

    try:
        source_bucket = storage_client.bucket(bucket_name)
        source_blob = source_bucket.blob(file_name)

        if not source_blob.exists():
            logger.error("Le blob source gs://%s/%s n'existe plus.", bucket_name, file_name)
            return

        destination_bucket = storage_client.bucket(RAW_ZONE_BUCKET)
        destination_blob_name = f"{PENDING_PREFIX}{file_name}"

        source_bucket.copy_blob(source_blob, destination_bucket, destination_blob_name)
        source_bucket.delete_blob(file_name)

        logger.info(
            "Déplacé: gs://%s/%s -> gs://%s/%s",
            bucket_name, file_name, RAW_ZONE_BUCKET, destination_blob_name
        )
    except Exception as exc:
        logger.error("Erreur lors du déplacement de gs://%s/%s: %s", bucket_name, file_name, exc)
        raise
