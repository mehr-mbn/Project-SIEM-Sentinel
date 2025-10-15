# Phase 2 – Data Connectors

## Azure Activity (Subscription-level → Log Analytics)

**Goal:** Collect control-plane operations (resource creation, policy changes, RBAC updates) at the subscription scope and route them to the Sentinel workspace.

**Context:** The Azure Activity log is subscription-scoped, not resource-group–scoped.  
Because of this, the `az monitor diagnostic-settings create` command can throw `KeyError: 'resource_group'` on some CLI versions.  
To avoid version-specific issues, the connection was created using a REST API call.

### Configuration (via Azure REST)
```bash
SUB=$(az account show --query id -o tsv)
RG=rg-siem-demo
WS=law-siem-demo
WSID=$(az monitor log-analytics workspace show -g $RG -n $WS --query id -o tsv)

az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/microsoft.insights/diagnosticSettings?api-version=2021-05-01-preview" \
  --query "value[].{Name:name, Logs:join(', ', [].properties.logs[].category)}" -o table

az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/providers/microsoft.insights/diagnosticSettings/ActivityToLAW-today?api-version=2021-05-01-preview" \
  --body "{
    \"properties\": {
      \"workspaceId\": \"$WSID\",
      \"logs\": [
        { \"category\": \"Administrative\",   \"enabled\": true },
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


## Validation (KQL)

AzureActivity
| where TimeGenerated > ago(30m)
| summarize Events=count() by CategoryValue, bin(TimeGenerated, 15m)
| order by TimeGenerated desc

## Expected output:
Records appear with categories such as Administrative, Policy, or Security.
Once the table AzureActivity populates, Sentinel analytics can correlate those changes with incidents.

## Conflict rule
A given category (for example, Administrative) cannot send to the same Log Analytics workspace via multiple diagnostic settings for the same resource.
If such duplication is attempted, Azure returns a Conflict (409) error similar to:

"Data sink ... is already used in diagnostic setting ... for category 'Administrative'."

## Solution:
Update the existing diagnostic setting to include all required categories, or delete the old one and create a single consolidated configuration.

##Summary
Item	       Value
Resource     scope	Subscription
Diagnostic   setting name	ActivityToLAW-today
Destination	 law-siem-demo (Log Analytics Workspace)
Categories   enabled	8 (Administrative, Security,ServiceHealth, Alert, Recommendation, Policy, Autoscale, ResourceHealth)
Verification query	AzureActivity
Result	     ✅ Data successfully ingested


## Microsoft Entra ID → Log Analytics

**Goal:** Collect tenant-level identity telemetry for correlation and detection of suspicious sign-ins or directory changes.

### Configuration
1. Entra admin center → Monitoring & health → Diagnostic settings → Add  
2. Destination: Send to Log Analytics workspace `law-siem-demo`  
3. Categories enabled:
   - AuditLogs  
   - SignInLogs  
   - (Optional) NonInteractiveUserSignInLogs, ServicePrincipalSignInLogs, ManagedIdentitySignInLogs, ProvisioningLogs  
4. Save.

### Validation (KQL)
Each query must be run separately or separated by a semicolon (`;`):

```kusto
SigninLogs | where TimeGenerated > ago(30m) | take 5;
AuditLogs  | where TimeGenerated > ago(30m) | take 5


## Expected output:
Rows returned from both tables confirming log ingestion from Entra ID.

## Notes:

*If no results appear, trigger sign-ins (failed or successful) or make a small admin-level change in Entra ID to generate events.

*Diagnostic settings for Entra ID are tenant-scoped, so they do not appear inside the resource group or workspace blade.

*Typical propagation delay is 5–10 minutes after saving the setting.

## Summary:

Item	                 Value
Scope	Tenant           (Microsoft Entra ID)
Destination	           law-siem-demo (Log Analytics Workspace)
Categories	           AuditLogs, SigninLogs (+ optional others)
Verification queries	 SigninLogs, AuditLogs
Result	               ✅ Data successfully ingested