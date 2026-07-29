# ADR-001 : Structure à 3 états pour raw-zone (pending/processing/processed)

**Statut :** Adopté

## Contexte

La structure initiale de raw-zone ne comportait que 2 états : `pending/`
(fichier arrivé, non traité) et `processed/` (fichier traité). Sur
proposition de M. Amara, un état intermédiaire `processing/` a été ajouté
avant que le pipeline PySpark/Airflow ne soit implémenté.

## Problème identifié

Avec seulement 2 états, il est impossible de distinguer "fichier jamais
traité" de "fichier en cours de traitement" en cas d'échec du job à
mi-parcours, ou d'exécution concurrente accidentelle — risque de double
traitement ou de perte de traçabilité en cas de panne.

## Décision

Adoption d'une structure à 3 états :

pending/ -> fichier arrivé, en attente
processing/ -> fichier en cours de lecture (verrou explicite)
processed/ -> fichier confirmé traité


Le déplacement `pending -> processing -> processed` sera géré par le job
PySpark/Airflow (Semaine 2-3), pas par la Cloud Run Function de routage
initial (Semaine 1), qui se limite à déposer les fichiers dans `pending/`.

## Conséquences

- Un fichier bloqué en `processing/` après un crash est immédiatement
  identifiable pour investigation, sans ambiguïté sur son état réel.
- Aucun changement rétroactif nécessaire sur la Cloud Run Function déjà
  développée.
