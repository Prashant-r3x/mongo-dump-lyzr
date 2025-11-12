"""
Script to add WTW Common AI Platform provider to MongoDB
"""
import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from datetime import datetime

# MongoDB connection string from .env
MONGO_URL = "mongodb://ebticpdna21aiorchcosmosdb:NzIua1pPr4C6L8ItLwI4falLsn4cVrgg4bp3HR6MF3rWsdrpsb4Ml1wejAekpKlbLKcX5AnZn3XnACDbTqZc0w==@ebticpdna21aiorchcosmosdb.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@ebticpdna21aiorchcosmosdb@"

async def add_wtw_provider():
    """Add WTW provider to MongoDB"""

    # Connect to MongoDB
    client = AsyncIOMotorClient(MONGO_URL)
    db = client["factory_dev"]

    # Check if WTW provider already exists
    existing = await db["providers"].find_one({"provider_id": "WTW"})

    if existing:
        print("✅ WTW provider already exists")
        print(f"   Provider ID: {existing.get('provider_id')}")
        print(f"   Display Name: {existing.get('display_name')}")
        return

    # WTW provider document
    wtw_provider = {
        "provider_id": "WTW",
        "type": "lyzr-llm",
        "display_name": "WTW Common AI",
        "priority": 1,  # High priority to show near the top
        "meta_data": {
            "credential_id": None,  # No credentials needed (uses Azure Managed Identity)
            "models": [
                # All available models (union of dev and prod)
                "gpt-4.1",
                "gpt-4.1-mini",
                "gpt-4.1-nano",
                "gpt-4o",
                "gpt-4o-mini",
                "gpt-5",
                "gpt-5-mini",
                "gpt-5-nano",
                "o1",
                "o1-mini",  # Only in prod
                "o3",
                "o3-mini",
                "o4-mini",
            ]
        },
        "disabled": [],  # No disabled models
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    }

    # Insert the provider
    result = await db["providers"].insert_one(wtw_provider)

    print(f"✅ WTW provider added successfully!")
    print(f"   Provider ID: {wtw_provider['provider_id']}")
    print(f"   Display Name: {wtw_provider['display_name']}")
    print(f"   MongoDB _id: {result.inserted_id}")
    print(f"   Available Models: {len(wtw_provider['meta_data']['models'])}")

    # Close connection
    client.close()


if __name__ == "__main__":
    print("=" * 70)
    print("Adding WTW Common AI Platform Provider to MongoDB")
    print("=" * 70)

    asyncio.run(add_wtw_provider())

    print("\n" + "=" * 70)
    print("Done! WTW provider is now available in the UI.")
    print("=" * 70)
