====================================================================
PHASE 4 – SENTINEL AUTOMATION PLAYBOOK SETUP GUIDE
====================================================================
Purpose: Redeploy and reconnect the Sentinel automation playbook (pb-incident-add-comment-v2)
====================================================================

1️⃣ PREREQUISITES
--------------------------------------------------------------------
• Resource Group: rg-siem-demo
• Region: canadacentral
• Log Analytics Workspace: law-siem-demo
• Microsoft Sentinel enabled on workspace
• Azure CLI logged in with appropriate permissions

--------------------------------------------------------------------
2️⃣ RECREATE LOGIC APP (PLAYBOOK)
--------------------------------------------------------------------
If deleted, recreate the playbook via Azure Portal or ARM template.

Manual creation steps:
  - Go to: Azure Portal → Create a resource → Logic App (Consumption)
  - Name: pb-incident-add-comment-v2
  - Region: canadacentral
  - Resource Group: rg-siem-demo

Then open the Logic App Designer and add:
  Trigger:
      → When a Microsoft Sentinel incident is created
  Action:
      → Add comment to incident (V3)

Parameters:
  • Incident ARM ID:
        @triggerBody()?['object']?['id']
  • Comment:
        Playbook auto-comment: Incident received by Logic App.

--------------------------------------------------------------------
3️⃣ CREATE API CONNECTION
--------------------------------------------------------------------
Run these commands if the connection is missing or broken:

SUB=$(az account show --query id -o tsv)
RG=rg-siem-demo
LOC=canadacentral

az resource create \
  -g $RG \
  -n azuresentinel \
  --resource-type "Microsoft.Web/connections" \
  --location $LOC \
  --properties "{
    \"displayName\": \"azuresentinel\",
    \"api\": {
      \"id\": \"/subscriptions/$SUB/providers/Microsoft.Web/locations/$LOC/managedApis/azuresentinel\"
    },
    \"parameterValues\": {}
  }"

⚠️ After running the command:
   → Go to Portal → Resource Group → azuresentinel (API Connection)
   → Click “Edit API Connection”
   → Press “Authorize” and then “Save”

--------------------------------------------------------------------
4️⃣ LINK CONNECTION TO PLAYBOOK
--------------------------------------------------------------------
Once API connection is authenticated, link it to the Logic App:

WF=pb-incident-add-comment-v2
SUB=$(az account show --query id -o tsv)
RG=rg-siem-demo
LOC=canadacentral

az resource update \
  -g $RG \
  -n $WF \
  --resource-type "Microsoft.Logic/workflows" \
  --set "properties.parameters.azureSentinelConnectionName.value=azuresentinel"

--------------------------------------------------------------------
5️⃣ ROLE ASSIGNMENTS
--------------------------------------------------------------------
The Logic App identity must have the following roles at workspace scope:

WSID=$(az resource show -g rg-siem-demo -n law-siem-demo \
  --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv)
PBID=$(az resource show -g rg-siem-demo -n pb-incident-add-comment-v2 \
  --resource-type Microsoft.Logic/workflows --query identity.principalId -o tsv)
SENTINEL_SP=$(az ad sp list --display-name "Azure Security Insights" \
  --query "[0].id" -o tsv)

az role assignment create --assignee-object-id $PBID \
  --assignee-principal-type ServicePrincipal \
  --role "Microsoft Sentinel Responder" \
  --scope "$WSID"

az role assignment create --assignee $SENTINEL_SP \
  --role "Logic App Contributor" \
  --scope "$WSID"

--------------------------------------------------------------------
6️⃣ VALIDATION
--------------------------------------------------------------------
To confirm functionality:
  - In Sentinel → Incidents → Run Playbook → Select “pb-incident-add-comment-v2”
  - Wait 10–15 seconds
  - Open Incident → Comments tab → Verify:
        “Playbook auto-comment: Incident received by Logic App.”

--------------------------------------------------------------------
7️⃣ OPTIONAL CLEANUP
--------------------------------------------------------------------
To remove old diagnostic or duplicate data sources:
  az monitor diagnostic-settings list --resource /subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/$WS
