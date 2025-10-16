#!/usr/bin/env bash
set -euo pipefail
RG=rg-siem-demo
LOC=canadacentral
WS=law-siem-demo
DCR=dcr-syslog
VM=vm1

WSID=$(az monitor log-analytics workspace show -g $RG -n $WS --query id -o tsv)
SUB=$(az account show --query id -o tsv)

az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Insights/dataCollectionRules/$DCR?api-version=2022-06-01" \
  --body "{
    \"location\": \"$LOC\",
    \"properties\": {
      \"dataSources\": { \"syslog\": [ { \"name\": \"syslogSource\", \"streams\": [\"Microsoft-Syslog\"], \"facilityNames\": [\"auth\",\"authpriv\"], \"logLevels\": [\"Notice\",\"Warning\",\"Error\",\"Critical\",\"Alert\",\"Emergency\",\"Info\"] } ] },
      \"destinations\": { \"logAnalytics\": [ { \"name\": \"la1\", \"workspaceResourceId\": \"$WSID\" } ] },
      \"dataFlows\": [ { \"streams\": [\"Microsoft-Syslog\"], \"destinations\": [\"la1\"] } ]
    }
  }"

VMID=$(az vm show -g $RG -n $VM --query id -o tsv)
DCRID=$(az monitor data-collection rule show -g $RG -n $DCR --query id -o tsv)
az monitor data-collection rule association create --name dcrassoc-syslog-$VM --rule-id "$DCRID" --resource "$VMID"

az vm run-command invoke -g $RG -n $VM --command-id RunShellScript --scripts 'sudo systemctl restart azuremonitoragent'
