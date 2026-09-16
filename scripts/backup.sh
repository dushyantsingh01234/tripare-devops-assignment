#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/backup.sh [output_dir]
# Runs pg_dump against the local compose Postgres and writes a timestamped .sql.gz.

OUT_DIR="${1:-./backups}"
CONTAINER="${DB_CONTAINER:-booking-db}"
PGUSER_="${POSTGRES_USER:-app}"
PGDB="${POSTGRES_DB:-booking}"

mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="$OUT_DIR/${PGDB}_${TS}.sql.gz"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "container '$CONTAINER' is not running - start it with: docker compose up -d" >&2
    exit 1
fi

echo "Dumping ${PGDB} from ${CONTAINER} -> ${OUT_FILE}"

# --clean/--if-exists so restore into an existing DB is idempotent.
docker exec -i "$CONTAINER" \
    pg_dump -U "$PGUSER_" -d "$PGDB" \
        --format=plain --clean --if-exists --no-owner --no-privileges \
    | gzip -9 > "$OUT_FILE"

BYTES="$(wc -c < "$OUT_FILE" | tr -d ' ')"
echo "wrote ${OUT_FILE} (${BYTES} bytes)"

# TODO: aws s3 cp to a versioned bucket once IAM is set up on the runner box.
