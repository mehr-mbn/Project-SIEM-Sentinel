#!/usr/bin/env bash
set -euo pipefail
RG=rg-siem-demo
WS=law-siem-demo
SUB=$(az account show --query id -o tsv)
WSID=$(az monitor log-analytics workspace show -g $RG -n $WS --query id -o tsv)

az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/providers/microsoft.insights/diagnosticSettings/ActivityToLAW-today?api-version=2021-05-01-preview" \
  --body "{
    \"properties\": {
      \"workspaceId\": \"$WSID\",
      \"logs\": [
        { \"category\": \"Administrative\",  \"enabled\": true },
        { \"category\": \"Security\",        \"enabled\": true },
        { \"category\": \"ServiceHealth\",   \"enabled\": true },
        { \"category\": \"Alert\",           \"enabled\": true },
        { \"category\": \"Recommendation\",  \"enabled\": true },
        { \"category\": \"Policy\",          \"enabled\": true },
        { \"category\": \"Autoscale\",       \"enabled\": true },
        { \"category\": \"ResourceHealth\",  \"enabled\": true }
      ],
      \"metrics\": []
    }
  }"
