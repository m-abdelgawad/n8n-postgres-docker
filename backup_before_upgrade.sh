#!/bin/bash
set -e

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
BACKUP_ROOT="./upgrade-backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARGET_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

POSTGRES_CONTAINER="postgres_db"
DB_NAME="n8n"
DB_USER="dbuser"

N8N_CONTAINER="n8n"

echo "[STEP 0] Initializing backup sequence..."

# -------------------------------------------------------------------
# Create folder structure
# -------------------------------------------------------------------
echo "[STEP 1] Creating backup directory at: ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

# -------------------------------------------------------------------
# Database Backup
# -------------------------------------------------------------------
echo "[STEP 2] Dumping PostgreSQL database..."
# We redirect stdout to a file so the file is owned by the host user (mohamed), not root
docker exec -t "${POSTGRES_CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" > "${TARGET_DIR}/db_backup.sql"

echo "[OK] Database dump saved to ${TARGET_DIR}/db_backup.sql"

# -------------------------------------------------------------------
# Volumes Backup (n8n_data and n8n_binary_data)
# -------------------------------------------------------------------
# FIX: using tar to stdout (>) ensures the file is owned by the current user (mohamed)
# preventing "Operation not permitted" errors during chmod later.

echo "[STEP 3] Creating volume tarball: n8n_data"
docker run --rm \
  -v n8n_data:/data \
  alpine tar -C /data -czf - . > "${TARGET_DIR}/n8n_data.tar.gz"

echo "[STEP 4] Creating volume tarball: n8n_binary_data"
docker run --rm \
  -v n8n_binary_data:/data \
  alpine tar -C /data -czf - . > "${TARGET_DIR}/n8n_binary_data.tar.gz"

# -------------------------------------------------------------------
# Workflow & Credentials Export
# -------------------------------------------------------------------
echo "[STEP 5] Exporting workflows..."

TEMP_CONTAINER_PATH="/home/node/.n8n/upgrade_backup_${TIMESTAMP}"

# Create temp folder inside container
docker exec -u node "${N8N_CONTAINER}" mkdir -p "${TEMP_CONTAINER_PATH}"

# Export workflows
# FIX: Added -e N8N_RUNNERS_MODE=internal to silence the "Invalid enum" error during CLI use
docker exec -u node -e N8N_RUNNERS_MODE=internal "${N8N_CONTAINER}" \
  n8n export:workflow --backup --output="${TEMP_CONTAINER_PATH}" || { echo "ERROR: export:workflow failed"; exit 1; }

echo "[STEP 6] Exporting credentials..."

# Export credentials
# FIX: Added -e N8N_RUNNERS_MODE=internal here as well
docker exec -u node -e N8N_RUNNERS_MODE=internal "${N8N_CONTAINER}" \
  n8n export:credentials --backup --output="${TEMP_CONTAINER_PATH}" || { echo "ERROR: export:credentials failed"; exit 1; }

# Copy folder out to host
docker cp "${N8N_CONTAINER}:${TEMP_CONTAINER_PATH}/." "${TARGET_DIR}/" || { echo "ERROR: docker cp failed"; exit 1; }

# Cleanup: Remove the temp folder inside the container
docker exec -u node "${N8N_CONTAINER}" rm -rf "${TEMP_CONTAINER_PATH}"

echo "[OK] Workflows and credentials exported."

# -------------------------------------------------------------------
# Permissions summary
# -------------------------------------------------------------------
# This should now succeed because all files are owned by the current user
chmod -R 700 "${TARGET_DIR}"

echo "------------------------------------------------------"
echo "[SUCCESS] All backups completed."
echo "Backup Location: ${TARGET_DIR}"
echo "Contents:"
echo " - db_backup.sql"
echo " - n8n_data.tar.gz"
echo " - n8n_binary_data.tar.gz"
echo " - (exported workflow/credential JSON files)"
echo "------------------------------------------------------"

exit 0
