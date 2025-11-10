#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# USER CONFIGURATION
# -------------------------
SUBSCRIPTION_ID="608a6efb-6c29-4892-8e7f-2703461e5b06"
RESOURCE_GROUP="EBTICP-D-NA21-AIOrch-RGRP"
COSMOS_ACCOUNT_NAME="ebticpdna21aiorchcosmosdb"
MONGO_DUMP_PATH="./mongo-dump"  # Local path to your dump folder

# -------------------------
# 1️⃣  LOGIN & SET CONTEXT
# -------------------------
echo "🔐 Logging into Azure..."
az account show >/dev/null 2>&1 || az login
az account set --subscription "$SUBSCRIPTION_ID"
echo "✅ Azure subscription context set to: $SUBSCRIPTION_ID"

# -------------------------
# 2️⃣  CHECK MONGORESTORE
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
# 3️⃣  GET COSMOS CONNECTION STRING
# -------------------------
echo "🔍 Fetching Cosmos DB Mongo connection string..."
COSMOS_CONNECTION_STRING=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" \
  -o tsv)

if [[ -z "$COSMOS_CONNECTION_STRING" ]]; then
  echo "❌ Failed to retrieve Cosmos DB connection string"
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
    echo "⬆️ Restoring database: $FROM_DB"
    mongorestore \
      --uri="$COSMOS_CONNECTION_STRING" \
      --nsInclude="${FROM_DB}.*" \
      --numInsertionWorkersPerCollection=1 \
      --batchSize=1 \
      --drop \
      "$MONGO_DUMP_PATH"
  else
    echo "🔄 Restoring $TO_DB (from $FROM_DB data)"
    mongorestore \
      --uri="$COSMOS_CONNECTION_STRING" \
      --nsFrom="${FROM_DB}.*" \
      --nsTo="${TO_DB}.*" \
      --numInsertionWorkersPerCollection=1 \
      --batchSize=1 \
      --drop \
      "$MONGO_DUMP_PATH"
  fi
  echo "✅ $TO_DB restored successfully."
}

# Run restores
restore_database "factory_dev" "factory_dev"
restore_database "agent_studio_dev" "agent_studio_dev"
restore_database "factory_dev" "factory"
restore_database "agent_studio_dev" "agent_studio"

# -------------------------
# 5️⃣  SUMMARY
# -------------------------
echo ""
echo "🎯 Mongo restore completed successfully!"
echo "Databases restored:"
echo "  - factory_dev"
echo "  - agent_studio_dev"
echo "  - factory"
echo "  - agent_studio"
echo ""
echo "⚠️ If you see 'Error 16500 (rate limiting)',"
echo "increase Cosmos DB throughput and rerun the script."

