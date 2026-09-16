#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/restore.sh <backup_file.sql.gz> [target_db]
# Drops the target DB, recreates it empty, and streams the dump back in.

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <backup_file.sql.gz> [target_db]" >&2
    exit 2
fi

BACKUP_FILE="$1"
TARGET_DB="${2:-${POSTGRES_DB:-booking}_restore}"
CONTAINER="${DB_CONTAINER:-booking-db}"
PGUSER_="${POSTGRES_USER:-app}"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "backup file not found: $BACKUP_FILE" >&2
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "container '$CONTAINER' is not running - start it with: docker compose up -d" >&2
    exit 1
fi

echo "Restoring ${BACKUP_FILE} -> ${CONTAINER}:${TARGET_DB}"

# Recreate the target DB from scratch so this always lands in a clean state.
docker exec -i "$CONTAINER" psql -U "$PGUSER_" -d postgres -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ${TARGET_DB};
CREATE DATABASE ${TARGET_DB} OWNER ${PGUSER_};
SQL

gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER" \
    psql -U "$PGUSER_" -d "$TARGET_DB" -v ON_ERROR_STOP=1 -q

echo
echo "restore complete - quick sanity check:"
docker exec -i "$CONTAINER" psql -U "$PGUSER_" -d "$TARGET_DB" -A -t <<'SQL'
SELECT 'hotel_bookings=' || COUNT(*) FROM hotel_bookings;
SELECT 'booking_events=' || COUNT(*) FROM booking_events;
SQL
