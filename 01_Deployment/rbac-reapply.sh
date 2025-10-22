#!/usr/bin/env bash
set -euo pipefail
RG=rg-siem-demo
WSID=$(az resource show -g $RG -n law-siem-demo --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv)
WFID=$(az resource show -g $RG -n pb-incident-add-comment-v2 --resource-type Microsoft.Logic/workflows --query id -o tsv)
PBID=$(az resource show -g $RG -n pb-incident-add-comment-v2 --resource-type Microsoft.Logic/workflows --query identity.principalId -o tsv)
SENTINEL_SP=$(az ad sp list --display-name "Azure Security Insights" --query "[0].id" -o tsv)

az role assignment create --assignee-object-id "$PBID" --assignee-principal-type ServicePrincipal --role "Microsoft Sentinel Responder" --scope "$WSID" || true
az role assignment create --assignee "$SENTINEL_SP" --role "Logic App Contributor" --scope "$WFID" || true
echo "RBAC re-applied."
