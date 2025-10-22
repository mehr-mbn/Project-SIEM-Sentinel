#!/usr/bin/env bash
set -euo pipefail
RG=rg-siem-demo
VM=vm1
az vm extension set \
  --publisher Microsoft.Azure.Monitor \
  --name AzureMonitorLinuxAgent \
  --resource-group $RG \
  --vm-name $VM
echo "AMA extension set on $VM"
