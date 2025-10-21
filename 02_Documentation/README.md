# Azure SIEM Sentinel Project

End-to-end deployment of a minimal but production-aligned SIEM stack in Azure:
Log Analytics Workspace + Microsoft Sentinel + Data Connectors + Syslog ingestion via Azure Monitor Agent.

---

## ✅ Phase 1 – Log Analytics Workspace + Sentinel

**Commands used:**  
`az group create`, `az monitor log-analytics workspace create`, `az monitor log-analytics solution create`

**Results:**  
- Resource Group `rg-siem-demo`  
- Workspace `law-siem-demo` (Canada Central)  
- Sentinel solution `SecurityInsights(law-siem-demo)` installed  
- Verified via CLI and Portal

**Screenshot:**  
![Phase 1 Complete](./screenshots/phase1-law-sentinel-complete.png)

---

## ✅ Phase 2 A – Azure Activity Logs Connector

**Goal:** Stream subscription-level Activity Logs into the workspace.

**Command:**  
```bash
az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/providers/microsoft.insights/diagnosticSettings/ActivityToLAW-today?api-version=2021-05-01-preview" \
  --body '{
     "properties":{
       "workspaceId":"<LAW-ID>",
       "logs":[
         {"category":"Administrative","enabled":true},
         {"category":"Security","enabled":true},
         {"category":"ServiceHealth","enabled":true},
         {"category":"Alert","enabled":true},
         {"category":"Recommendation","enabled":true},
         {"category":"Policy","enabled":true},
         {"category":"Autoscale","enabled":true},
         {"category":"ResourceHealth","enabled":true}
       ]
     }
   }'



### Verification:

az rest --method get \
 --url "https://management.azure.com/subscriptions/$SUB/providers/microsoft.insights/diagnosticSettings?api-version=2021-05-01-preview" \
 --query "value[].{Name:name, Categories:length(properties.logs)}" -o table

#Output:
Name                 Categories
-------------------  ------------
ActivityToLAW-today  8

## Conflict Rule:
A given log category (e.g. Administrative) cannot be duplicated in multiple diagnostic settings for the same resource.


✅ Phase 2 B – Entra ID (Audit & Sign-in Logs)

Configured via Portal → Microsoft Sentinel → Data Connectors → Microsoft Entra Logs

## Verification Queries:

AuditLogs  | where TimeGenerated > ago(30m) | take 5
SigninLogs | where TimeGenerated > ago(30m) | take 5


# Result:
Data successfully ingested for both tables.




✅ Phase 3 A – VM + Azure Monitor Agent (AMA)

# Goal: Forward Linux syslog events from a VM (vm1) to Sentinel.

# Validation:

az vm extension show -g rg-siem-demo -n AzureMonitorLinuxAgent \
  --vm-name vm1 --query "{ProvisioningState:provisioningState, type:typeHandlerVersion}" -o table


# Output:

ProvisioningState
-----------------
Succeeded

✅ Phase 3 B – Syslog Data Collection Rule (DCR)

# Key Parameters:

Facilities: auth, authpriv

Stream: Microsoft-Syslog

Destination: LAW (law-siem-demo)

Associated VM: vm1 (with Managed Identity enabled)

# Validation Queries:

Syslog
| where TimeGenerated > ago(30m)
| where Facility in ("auth","authpriv")
| where SyslogMessage has_any ("Failed password","Accepted password","Invalid user",
                               "authentication failure","Failed publickey","Permission denied (publickey)")
| project TimeGenerated, Computer, Facility, SyslogMessage
| order by TimeGenerated desc


# Custom Test Message:

sudo logger -p auth.notice "mi-fixed-test-3"


# Results:
Syslog events and test message successfully ingested.


📄 Exported JSONs

# Located in /03_Exports/

resource-group.json

law-siem-demo.json

sentinel-solution.json

vm1.json

dcr-syslog.json

dcr-associations.json

diag-subscription.json


🧰 Deployment Scripts (Reproducible Build)

# All scripts are in /01_Deployment/

deploy-law-and-sentinel.sh

deploy-vm.sh

deploy-dcr.sh

deploy-activity-diag.sh

Run sequentially to rebuild the full environment.

📊 Summary
Phase	Purpose	Status	Validation
1	Deploy Log Analytics Workspace + Sentinel	✅ Complete	Workspace + Solution Verified
2A	Subscription Activity Logs	✅ Complete	AzureActivity ingested
2B	Entra ID Audit & Sign-in Logs	✅ Complete	AuditLogs / SigninLogs tables
3A	VM with AMA installed	✅ Complete	AMA ProvisioningState = Succeeded
3B	Syslog collection via DCR + Association	✅ Complete	Syslog events & test message ingested
