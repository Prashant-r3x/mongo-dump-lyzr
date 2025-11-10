#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# CONFIGURATION PARAMETERS
# -------------------------
AZURE_SUBSCRIPTION="wtw-ai-orch-deploy-dev-svc-connection"
AZURE_LOCATION="centralus"
RESOURCE_GROUP="EBTICP-D-NA21-AIOrch-RGRP"
COSMOS_ACCOUNT_NAME="ebticpdna21aiorchcosmosdb"
MONGO_DUMP_PATH="./mongo-dump"  # Path where your Mongo dump is located

# -------------------------
# 1️⃣  LOGIN TO AZURE (if not already)
# -------------------------
echo "🔐 Logging into Azure..."
az account show >/dev/null 2>&1 || az login
az account set --subscription "$AZURE_SUBSCRIPTION"
echo "✅ Azure subscription set: $AZURE_SUBSCRIPTION"

# -------------------------
# 2️⃣  INSTALL MONGODB DATABASE TOOLS (if not installed)
# -------------------------
if ! command -v mongorestore &> /dev/null; then
  echo "⚙️ Installing MongoDB Database Tools..."
  wget -q https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.9.4.deb -O mongodb-tools.deb
  sudo dpkg -i mongodb-tools.deb
  rm -f mongodb-tools.deb
else
  echo "✅ MongoDB Tools already installed."
fi

mongorestore --version

# -------------------------
# 3️⃣  GET COSMOS DB CONNECTION STRING
# -------------------------
echo "🔍 Retrieving Cosmos DB connection string..."
COSMOS_CONNECTION_STRING=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" \
  -o tsv)

if [[ -z "$COSMOS_CONNECTION_STRING" ]]; then
  echo "❌ Failed to retrieve Cosmos DB connection string."
  exit 1
fi

echo "✅ Connection string retrieved."

# -------------------------
# 4️⃣  RESTORE DATABASES
# -------------------------
restore_database() {
  local FROM_DB=$1
  local TO_DB=$2

  if [[ "$FROM_DB" == "$TO_DB" ]]; then
    echo "⬆️ Restoring $FROM_DB..."
    mongorestore \
      --uri="$COSMOS_CONNECTION_STRING" \
      --nsInclude="${FROM_DB}.*" \
      --numInsertionWorkersPerCollection=1 \
      --batchSize=1 \
      --drop \
      "$MONGO_DUMP_PATH"
    echo "✅ $FROM_DB restored successfully."
  else
    echo "🔄 Restoring $TO_DB (from $FROM_DB data)..."
    mongorestore \
      --uri="$COSMOS_CONNECTION_STRING" \
      --nsFrom="${FROM_DB}.*" \
      --nsTo="${TO_DB}.*" \
      --numInsertionWorkersPerCollection=1 \
      --batchSize=1 \
      --drop \
      "$MONGO_DUMP_PATH"
    echo "✅ $TO_DB restored successfully."
  fi
}

# factory_dev
restore_database "factory_dev" "factory_dev"

# agent_studio_dev
restore_database "agent_studio_dev" "agent_studio_dev"

# factory (from factory_dev)
restore_database "factory_dev" "factory"

# agent_studio (from agent_studio_dev)
restore_database "agent_studio_dev" "agent_studio"

# -------------------------
# 5️⃣  SUMMARY
# -------------------------
echo ""
echo "🎯 All databases restored successfully:"
echo "  - factory_dev"
echo "  - agent_studio_dev"
echo "  - factory"
echo "  - agent_studio"
echo ""
echo "⚠️ Note: If you encounter 'Error 16500' (rate limiting),"
echo "increase Cosmos DB throughput and rerun the script."

B
