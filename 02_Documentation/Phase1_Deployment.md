# Phase 1 – Infrastructure Setup

## Objective
Deploy a clean Microsoft Sentinel lab environment using CLI commands for consistent and repeatable setup.

## Deployment Steps
1. Created Resource Group `rg-siem-demo` in **Canada Central**
2. Created Log Analytics Workspace `law-siem-demo` (30-day retention, daily cap 0.5 GB)
3. Enabled Microsoft Sentinel using REST API with `OMSGallery/SecurityInsights` solution

## CLI Script Reference
See: `/01_Infrastructure/deploy-law-and-sentinel.sh`

## Verification
```bash
az monitor log-analytics workspace show \
  --resource-group rg-siem-demo \
  --workspace-name law-siem-demo \
  --query "{Name:name, Region:location, Retention:retentionInDays}"


## Expected Output:
{
  "Name": "law-siem-demo",
  "Region": "canadacentral",
  "Retention": 30
}

## To verify Sentinel activation:
az resource show \
  -g rg-siem-demo \
  --resource-type "Microsoft.OperationsManagement/solutions" \
  -n "SecurityInsights(law-siem-demo)" \
  --api-version 2015-11-01-preview \
  --query "{Name:name, Type:type, Location:location}"

## Note: 
Retention for PerGB2018 SKU cannot be set below 30 days.

Daily quota ensures cost control.

The Sentinel resource must be created using az rest or az resource create --is-full-object because the legacy CLI command parameters are deprecated.

## Result: 
Microsoft Sentinel successfully enabled on Log Analytics Workspace law-siem-demo under region Canada Central.