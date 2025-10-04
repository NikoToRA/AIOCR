#!/usr/bin/env bash
set -euo pipefail

# Edit these variables
LOCATION="japaneast"
RG="koereq-ocr-rg"
STORAGE="koereqocr$RANDOM"
FUNCAPP="koereq-ocr-func-$RANDOM"
CONTAINER="raw"
DI_NAME="koereq-ocr-di-$RANDOM"

echo "Creating resource group" && az group create -n "$RG" -l "$LOCATION"

echo "Creating Storage Account" && az storage account create -g "$RG" -n "$STORAGE" -l "$LOCATION" --sku Standard_LRS
AZURE_STORAGE_KEY=$(az storage account keys list -g "$RG" -n "$STORAGE" --query "[0].value" -o tsv)
az storage container create --account-name "$STORAGE" --account-key "$AZURE_STORAGE_KEY" -n "$CONTAINER"

echo "Creating Document Intelligence (Cognitive Services)"
az cognitiveservices account create \
  -g "$RG" -n "$DI_NAME" -l "$LOCATION" \
  --kind FormRecognizer --sku S0 --yes
DI_ENDPOINT=$(az cognitiveservices account show -g "$RG" -n "$DI_NAME" --query properties.endpoint -o tsv)
DI_KEY=$(az cognitiveservices account keys list -g "$RG" -n "$DI_NAME" --query key1 -o tsv)

echo "Creating Function App (Python/Linux/Consumption)"
az functionapp create \
  -g "$RG" -n "$FUNCAPP" \
  --storage-account "$STORAGE" \
  --consumption-plan-location "$LOCATION" \
  --functions-version 4 \
  --runtime python --runtime-version 3.10

echo "Configuring app settings"
az functionapp config appsettings set -g "$RG" -n "$FUNCAPP" --settings \
  AZURE_STORAGE_ACCOUNT="$STORAGE" AZURE_STORAGE_KEY="$AZURE_STORAGE_KEY" AZURE_STORAGE_CONTAINER="$CONTAINER" \
  AZURE_DI_ENDPOINT="$DI_ENDPOINT" AZURE_DI_KEY="$DI_KEY"

echo "Reminder: Configure Azure OpenAI separately and set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY on the Function App."
echo "Then deploy from azure/functions with: func azure functionapp publish $FUNCAPP"

