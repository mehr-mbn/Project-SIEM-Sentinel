#!/bin/bash
# Phase 1 - Infrastructure Setup (Canada Central)
set -e

RG=rg-siem-demo
WS=law-siem-demo
LOC=canadacentral

echo "Creating Resource Group..."
az group create --name $RG --location $LOC

echo "Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name $WS \
  --location $LOC \
  --sku PerGB2018 \
  --retention-time 30

echo "Applying daily quota for cost control..."
az monitor log-analytics workspace update \
  --resource-group $RG \
  --workspace-name $WS \
  --quota 0.5

echo "Fetching workspace ID..."
SUB=$(az account show --query id -o tsv)
WSID=$(az monitor log-analytics workspace show -g $RG -n $WS --query id -o tsv)

echo "Enabling Microsoft Sentinel..."
az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationsManagement/solutions/SecurityInsights($WS)?api-version=2015-11-01-preview" \
  --body "{
    \"location\": \"$LOC\",
    \"plan\": {
      \"name\": \"SecurityInsights($WS)\",
      \"publisher\": \"Microsoft\",
      \"product\": \"OMSGallery/SecurityInsights\",
      \"promotionCode\": \"\"
    },
    \"properties\": {
      \"workspaceResourceId\": \"$WSID\"
    }
  }"

echo "Verifying Sentinel installation..."
az resource show \
  -g $RG \
  --resource-type "Microsoft.OperationsManagement/solutions" \
  -n "SecurityInsights($WS)" \
  --api-version 2015-11-01-preview \
  --query "{Name:name, Type:type, Location:location}" -o table

echo "Phase 1 complete ✅"
