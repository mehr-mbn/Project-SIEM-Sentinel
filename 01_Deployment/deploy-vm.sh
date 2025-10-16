#!/usr/bin/env bash
set -euo pipefail
RG=rg-siem-demo
LOC=canadacentral
VM=vm1

az vm create -g $RG -n $VM --image Ubuntu2204 --size Standard_B1s \
  --admin-username azureuser --generate-ssh-keys --location $LOC --public-ip-sku Standard
az vm open-port -g $RG -n $VM --port 22 --priority 300 || true
az vm extension set -g $RG --vm-name $VM --publisher Microsoft.Azure.Monitor --name AzureMonitorLinuxAgent
az vm identity assign -g $RG -n $VM
