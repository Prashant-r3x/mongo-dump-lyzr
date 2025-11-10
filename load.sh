#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# CONFIGURATION
# -------------------------
COSMOS_CONNECTION_STRING="mongodb://ebticpdna21aiorchcosmosdb:NzIua1pPr4C6L8ItLwI4falLsn4cVrgg4bp3HR6MF3rWsdrpsb4Ml1wejAekpKlbLKcX5AnZn3XnACDbTqZc0w==@ebticpdna21aiorchcosmosdb.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@ebticpdna21aiorchcosmosdb@"

MONGO_DUMP_PATH="./mongo-dump"

# -------------------------
# 1️⃣ CHECK MONGORESTORE
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
# 2️⃣ RESTORE DATABASES
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

echo ""
echo "🎯 All databases restored successfully."

