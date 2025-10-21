# Phase 4 – Automation & Incident Response (Logic App Playbook)

## 🎯 Objective
Implement automated response in Microsoft Sentinel by creating a **Logic App Playbook** that automatically adds a comment to every new Incident.

---

## 🧠 Overview
- **Trigger:** When a new incident is created in Microsoft Sentinel  
- **Action:** Add comment to the incident using the Azure Sentinel connector  
- **Authentication:** System-assigned Managed Identity + Azure Sentinel API connection (`azuresentinel`)  
- **Permissions:**
  - Playbook MI → `Microsoft Sentinel Responder` on LAW
  - Sentinel SP → `Logic App Contributor` on Playbook

---

## ⚙️ Deployment Summary

### 1️⃣ Create Azure Sentinel API Connection
```bash
az resource create \
  -g rg-siem-demo \
  -n azuresentinel \
  --resource-type "Microsoft.Web/connections" \
  --location canadacentral \
  --properties '{
    "displayName": "azuresentinel",
    "api": { "id": "/subscriptions/<SUB>/providers/Microsoft.Web/locations/canadacentral/managedApis/azuresentinel" },
    "parameterValues": {}
  }'

**Then Authorize the connection in Azure Portal 
Edit API connection → Authorize → Save**

2️⃣ Deploy Logic App Playbook

az deployment group create \
  -g rg-siem-demo \
  --template-file 01_Deployment/playbooks/pb-incident-add-comment-v2.json \
  --parameters location=canadacentral \
               connectionId="/subscriptions/<SUB>/resourceGroups/rg-siem-demo/providers/Microsoft.Web/connections/azuresentinel" \
               connectionManagedApiId="/subscriptions/<SUB>/providers/Microsoft.Web/locations/canadacentral/managedApis/azuresentinel"


3️⃣ Assign Required Roles

# Grant Logic App MI permissions to comment on incidents
WSID=$(az resource show -g rg-siem-demo -n law-siem-demo --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv)
PBID=$(az resource show -g rg-siem-demo -n pb-incident-add-comment-v2 --resource-type Microsoft.Logic/workflows --query identity.principalId -o tsv)
az role assignment create --assignee-object-id $PBID --assignee-principal-type ServicePrincipal --role "Microsoft Sentinel Responder" --scope "$WSID"

# Allow Sentinel to trigger the playbook
WFID=$(az resource show -g rg-siem-demo -n pb-incident-add-comment-v2 --resource-type Microsoft.Logic/workflows --query id -o tsv)
SENTINEL_SP=$(az ad sp list --display-name "Azure Security Insights" --query "[0].id" -o tsv)
az role assignment create --assignee $SENTINEL_SP --role "Logic App Contributor" --scope "$WFID"


4️⃣ Validate Playbook Functionality

1.Go to Microsoft Sentinel → Incidents

2.Select any active Incident → click Run playbook → pb-incident-add-comment-v2

3.Check Logic App → Run history: both actions green ✅

4.Open the Incident → Comments tab: you should see

Playbook auto-comment: Incident received by Logic App.


🧩 Verification Query

SecurityIncident
| where TimeGenerated > ago(1h)
| project TimeGenerated, Title, ProviderName, Description, IncidentNumber

Use this query to confirm that recent incidents include the auto-comment in Sentinel.

###Create Connection:
Create a connection called azuresentinel and authenticate it.

####Assign Permissions
Give required roles to the Logic App identity:

az role assignment create --assignee <LogicAppIdentity> --role "Microsoft Sentinel Responder" --scope <WorkspaceID>
az role assignment create --assignee <AzureSecurityInsightsSP> --role "Logic App Contributor" --scope <WorkspaceID>


📊 Outputs
Item	               Description
Playbook Name	       pb-incident-add-comment-v2
Connector	           Azure Sentinel (azuresentinel)
Trigger	             When a new Incident is created
Action	             Add comment to Incident
Authentication	     System-assigned Managed Identity
Run Result	         ✅ Succeeded
Comment Verified	   Yes
Role Assignments	   OK



🖼️ Screenshots (Evidence)
1️⃣ Logic App Overview

screenshots/phase4-overview.png

Shows Logic App in Enabled state and linked to Microsoft Sentinel.

2️⃣ Designer View

screenshots/phase4-designer-view.png

Displays the workflow connecting the trigger (Microsoft Sentinel incident) to the action (Add comment to incident V3).
Connected via the azuresentinel API connection.

3️⃣ Run History

screenshots/phase4-run-history.png

Demonstrates successful execution with Status: Succeeded.

4️⃣ Sentinel Incident Result

screenshots/phase4-incident-comment.png

Displays the final comment in the incident pane:

Playbook auto-comment: Incident received by Logic App.

🧠 Summary

This automation ensures every new Sentinel incident automatically receives a Logic App comment for better visibility and auditability.
It improves incident triage efficiency, analyst collaboration, and operational traceability across the SOC workflow.

Logic App deployed successfully

Connected securely to Microsoft Sentinel

Permissions configured and validated

Auto-comment verified on new incidents

Result: Automation phase completed successfully 🎯