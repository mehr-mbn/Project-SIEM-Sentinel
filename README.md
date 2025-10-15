# Microsoft Sentinel SIEM Lab

## 🧠 Project Overview
This project demonstrates a full deployment of Microsoft Sentinel on Azure, following cloud-native SIEM design principles and Azure Well-Architected Framework guidelines.

**Objectives**
- Deploy Microsoft Sentinel on a dedicated Log Analytics Workspace  
- Connect Entra ID, Azure Activity, and Syslog data sources  
- Implement detection rules (built-in and custom KQL)  
- Automate incident response via Logic Apps  
- Visualize data through custom workbooks  

**Scope**
| Component | Description |
|------------|-------------|
| Resource Group | `rg-siem-demo` |
| Log Analytics Workspace | `law-siem-demo` |
| Region | Canada Central |
| Retention | 30 days |
| Daily Quota | 0.5 GB |
| VM | Ubuntu (Syslog source) |

---

## ⚙️ Phase 1 – Infrastructure Setup

**Deployed Components**
- Resource Group: `rg-siem-demo`
- Log Analytics Workspace: `law-siem-demo`
- Microsoft Sentinel solution (`SecurityInsights(law-siem-demo)`)

**Key Commands**
```bash
az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationsManagement/solutions/SecurityInsights($WS)?api-version=2015-11-01-preview" \
  --body "{
    \"location\": \"canadacentral\",
    \"plan\": {
      \"name\": \"SecurityInsights($WS)\",
      \"publisher\": \"Microsoft\",
      \"product\": \"OMSGallery/SecurityInsights\",
      \"promotionCode\": \"\"
    },
    \"properties\": {
      \"workspaceResourceId\": \"$WSID\"
    }
  }"