#!/bin/bash
# =============================================================================
# MongoDB Import Script for WTW Sub-Organization Migration
#
# Two-step process:
#   1. mongorestore: imports ALL collections from BSON backup (preserves types)
#   2. mongoimport:  overwrites modified collections with transformed data
#
# Usage:
#   chmod +x import.sh
#   ./import.sh "mongodb+srv://user:pass@host/?tls=true&authMechanism=SCRAM-SHA-256&retrywrites=false"
# =============================================================================

set -e

CONN_STRING="${1:?Usage: ./import.sh <mongodb-connection-string>}"

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BSON_DIR="${SCRIPT_DIR}/mongo_backup"
MODIFIED_DIR="${SCRIPT_DIR}/modified"

PAGOS_DB="agent_studio_dev"
FACTORY_DB="factory_dev"

echo "============================================================"
echo "STEP 1: mongorestore — Import all BSON data (preserves types)"
echo "============================================================"

echo ""
echo "Restoring ${PAGOS_DB} (9 collections)..."
mongorestore \
  --uri="${CONN_STRING}" \
  --db="${PAGOS_DB}" \
  --dir="${BSON_DIR}/agent_studio_dev/" \
  --drop

echo ""
echo "Restoring ${FACTORY_DB} (27 collections)..."
mongorestore \
  --uri="${CONN_STRING}" \
  --db="${FACTORY_DB}" \
  --dir="${BSON_DIR}/factory_dev/" \
  --drop

echo ""
echo "============================================================"
echo "STEP 2: mongoimport — Overwrite with transformed data"
echo "============================================================"

# agent_studio_dev: 5 modified collections
for collection in organizations users policies keys usages; do
  echo ""
  echo "Importing ${PAGOS_DB}.${collection} (modified)..."
  mongoimport \
    --uri="${CONN_STRING}" \
    --db="${PAGOS_DB}" \
    --collection="${collection}" \
    --drop \
    --jsonArray \
    --file="${MODIFIED_DIR}/${collection}.json"
done

# factory_dev: credentials (2 docs remapped)
echo ""
echo "Importing ${FACTORY_DB}.credentials (modified)..."
mongoimport \
  --uri="${CONN_STRING}" \
  --db="${FACTORY_DB}" \
  --collection="credentials" \
  --drop \
  --jsonArray \
  --file="${MODIFIED_DIR}/factory_credentials.json"

echo ""
echo "============================================================"
echo "STEP 3: Verify counts"
echo "============================================================"

mongosh "${CONN_STRING}" --eval "
  const pagos = db.getSiblingDB('${PAGOS_DB}');
  const factory = db.getSiblingDB('${FACTORY_DB}');

  print('');
  print('${PAGOS_DB}:');
  print('  organizations: ' + pagos.organizations.countDocuments());
  print('  users:         ' + pagos.users.countDocuments());
  print('  policies:      ' + pagos.policies.countDocuments());
  print('  keys:          ' + pagos.keys.countDocuments());
  print('  usages:        ' + pagos.usages.countDocuments());
  print('  blueprints:    ' + pagos.blueprints.countDocuments());
  print('  views:         ' + pagos.views.countDocuments());
  print('  plans:         ' + pagos.plans.countDocuments());
  print('  rbac_roles:    ' + pagos.rbac_roles.countDocuments());

  print('');
  print('${FACTORY_DB}:');
  print('  agents:        ' + factory.agents.countDocuments());
  print('  workflows:     ' + factory.workflows.countDocuments());
  print('  credentials:   ' + factory.credentials.countDocuments());
  print('  rag_config:    ' + factory.rag_config.countDocuments());
  print('  providers:     ' + factory.providers.countDocuments());
  print('  tools_v2:      ' + factory.tools_v2.countDocuments());

  print('');
  print('Expected: 11 orgs, 62 users, 135 policies, 132 keys, 11 usages');
  print('          73 agents, 4 workflows, 7 credentials');
" 2>/dev/null || echo "(mongosh not available — verify counts manually)"

echo ""
echo "============================================================"
echo "DONE! Both databases imported successfully."
echo ""
echo "Next steps:"
echo "  1. Point your application to the new DB connection string"
echo "  2. Verify a user can log in and see their sub-org"
echo "  3. Verify existing agents still work"
echo "============================================================"
