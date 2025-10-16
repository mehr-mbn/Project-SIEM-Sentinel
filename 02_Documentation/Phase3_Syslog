# Phase 3 – Linux Syslog via AMA & DCR

## 3A. VM Provisioning & Agent Installation
**Objective:** Create an Ubuntu VM and install Azure Monitor Agent (AMA) to collect Syslog.

**Commands**
```bash
RG=rg-siem-demo
LOC=canadacentral
VM=vm1

az group create -n $RG -l $LOC
az vm create -g $RG -n $VM --image Ubuntu2204 --size Standard_B1s \
  --admin-username azureuser --generate-ssh-keys --location $LOC --public-ip-sku Standard --tags project=sentinel phase=3
az vm open-port -g $RG -n $VM --port 22 --priority 300
az vm extension set -g $RG --vm-name $VM --publisher Microsoft.Azure.Monitor --name AzureMonitorLinuxAgent


## Validation

az vm extension show -g $RG --vm-name $VM --name AzureMonitorLinuxAgent \
  --query "{provisioningState:provisioningState, type:typeHandlerVersion}" -o table

# Expected: provisioningState = Succeeded

## 3B. Data Collection Rule (Syslog → LAW)

**Objective:**  
Create a Data Collection Rule (DCR) that collects authentication-related Syslog events (`auth` and `authpriv`) from the Ubuntu VM and forwards them to the Sentinel Log Analytics Workspace (`law-siem-demo`).

---

### **Implementation (REST-based deployment)**

Some Azure CLI versions do not fully support the DCR creation parameters for Syslog (missing `--data-sources-syslog` flags).  
To ensure compatibility, the DCR was deployed using the Azure REST API with `api-version=2022-06-01`.

**Commands**
```bash
SUB=$(az account show --query id -o tsv)
WSID=$(az monitor log-analytics workspace show -g $RG -n law-siem-demo --query id -o tsv)

az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Insights/dataCollectionRules/dcr-syslog?api-version=2022-06-01" \
  --body "{
    \"location\": \"$LOC\",
    \"properties\": {
      \"dataSources\": {
        \"syslog\": [
          {
            \"name\": \"syslogSource\",
            \"streams\": [\"Microsoft-Syslog\"],
            \"facilityNames\": [\"auth\", \"authpriv\"],
            \"logLevels\": [\"Notice\",\"Warning\",\"Error\",\"Critical\",\"Alert\",\"Emergency\",\"Info\"]
          }
        ]
      },
      \"destinations\": {
        \"logAnalytics\": [
          {
            \"name\": \"la1\",
            \"workspaceResourceId\": \"$WSID\"
          }
        ]
      },
      \"dataFlows\": [
        {
          \"streams\": [\"Microsoft-Syslog\"],
          \"destinations\": [\"la1\"]
        }
      ]
    }
  }"


# Validation

az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Insights/dataCollectionRules/dcr-syslog?api-version=2022-06-01" \
  --query "{Name:name, Streams:properties.dataFlows[0].streams, DS_Streams:properties.dataSources.syslog[0].streams, Workspace:properties.destinations.logAnalytics[0].workspaceResourceId}" -o table

# Expected Output

Name        Streams           DS_Streams        Workspace
----------  ----------------  ----------------  ---------------------------------------------------------------
dcr-syslog  Microsoft-Syslog  Microsoft-Syslog  /subscriptions/.../law-siem-demo


## 3C.Associate DCR to VM

Overview

This phase configures Azure Monitor Agent (AMA) and a Data Collection Rule (DCR) to collect authentication logs from the Linux VM (vm1) and forward them to the Log Analytics Workspace (law-siem-demo).

✅ Configuration Summary
| Item | Value |
|------|-------|
| VM | vm1 |
| Region | Canada Central |
| Data Collection Rule | dcr-syslog |
| Facilities | auth, authpriv |
| Stream | Microsoft-Syslog |
| Destination | law-siem-demo |
| Identity | System-Assigned Managed Identity |
| Association | dcrassoc-syslog-vm1 |

### Deployment Steps
```bash
# Create Data Collection Rule (DCR):

az monitor data-collection rule create \
  --resource-group rg-siem-demo \
  --name dcr-syslog \
  --location canadacentral \
  --data-flows '[{"streams":["Microsoft-Syslog"],"destinations":["la1"]}]' \
  --destinations-log-analytics '[{"name":"la1","workspaceResourceId":"/subscriptions/.../law-siem-demo"}]' \
  --data-sources-syslog '[{"name":"syslogSource","streams":["Microsoft-Syslog"],"facilityNames":["auth","authpriv"],"logLevels":["Notice","Warning","Error","Critical","Alert","Emergency","Info"]}]'


# Associate DCR to VM:

VMID=$(az vm show -g rg-siem-demo -n vm1 --query id -o tsv)
DCRID=$(az monitor data-collection rule show -g rg-siem-demo -n dcr-syslog --query id -o tsv)
az monitor data-collection rule association create \
  --name dcrassoc-syslog-vm1 \
  --rule-id "$DCRID" \
  --resource "$VMID"


# Restart the Azure Monitor Agent:

az vm run-command invoke -g rg-siem-demo -n vm1 \
  --command-id RunShellScript --scripts 'sudo systemctl restart azuremonitoragent'

## Validation (KQL)

After producing SSH logins and test events:

Syslog
| where TimeGenerated > ago(30m)
| where Facility in ("auth","authpriv")
| project TimeGenerated, Computer, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc

---
⚠️ Common Issue: “Identity not found” / AMA Token Failure

**Error in mdsd.err:**

MSIToken ... Status code=400, error_description="Identity not found"
Failed to get MSI token from IMDS endpoint: http://169.254.169.254

### Root Cause

The Azure Monitor Agent requires a **System-Assigned Managed Identity (SAMI)** to obtain a token from IMDS.  
Without it, the agent cannot authenticate and will not send logs to the workspace.


##### Fix
# Assign a system-assigned managed identity to the VM
az vm identity assign -g rg-siem-demo -n vm1

# Restart the VM (important to refresh IMDS)
az vm restart -g rg-siem-demo -n vm1

# Restart the Azure Monitor Agent after reboot
az vm run-command invoke -g rg-siem-demo -n vm1 --command-id RunShellScript \
  --scripts 'sudo systemctl restart azuremonitoragent'


### Verify that IMDS responds correctly:

az vm run-command invoke -g rg-siem-demo -n vm1 --command-id RunShellScript --scripts '
curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/info?api-version=2020-06-01" || echo "IMDS curl failed"
'


When the Managed Identity and IMDS are both working, the AMA logs will stop printing MSI token errors and the Syslog data will appear in the LAW within 2–5 minutes.

#### ✅ Verification Result
| Test | Result |
|------|--------|
| IMDS reachable | ✅ |
| Managed Identity active | ✅ |
| AMA restarted successfully | ✅ |
| Syslog records in LAW | ✅ |
| SSH failed/success events visible | ✅ |


## Lessons Learned

Azure Monitor Agent absolutely requires a Managed Identity on Azure VMs when using DCRs.

If you see Identity not found or Failed to get MSI token, fix the identity before touching DCR or AMA config.

Always verify IMDS availability with curl http://169.254.169.254/metadata/identity/info.

After the fix, the ingestion pipeline restores itself automatically—no need to recreate DCRs.