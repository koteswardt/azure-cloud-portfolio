# OPS-CLOUD-009: 3-Tier Web Application Capstone

**Jira Ticket:** OPS-CLOUD-009
**Project:** Azure Cloud Journey — Phase 1 (Console)
**Owner:** Koteswar Rao
**Status:** ✅ Complete
**Completion Date:** 30 June 2026

> 📸 Full build screenshots (73 images across all 4 days) are indexed in [SCREENSHOTS.md](SCREENSHOTS.md)

---

## Jira Ticket

```
TICKET ID    : OPS-CLOUD-009
TITLE        : 3-Tier Web Application (Capstone)
PRIORITY     : Critical (Capstone — ties together OPS-CLOUD-001 through 008)
PHASE        : 1 — Azure Console (GUI)
COMPONENT    : Compute, Storage, Database, Security, Monitoring
REPORTER     : Koteswar Rao
ASSIGNEE     : Koteswar Rao
SPRINT       : Week 4
```

## What Problem Are We Trying To Solve

A startup needs a product catalogue web application. The requirement is not just "make it work" — it's **make it work the way a real engineering team would build it**:

- Customers need to see live product data from a real database, not a static page
- The backend must never store database credentials in source code, config files, or environment variables in plaintext — credentials in code are a recurring root cause of real-world breaches
- The team needs to know automatically when the API starts failing, before customers complain — without paying for an expensive observability stack
- The whole thing has to be inexpensive enough to run as a portfolio reference indefinitely

OPS-CLOUD-009 exists to prove these four problems can be solved together, hands-on, using only the Azure Portal — no scripts, no shortcuts, no copy-pasted Infrastructure as Code.

## What I Built

A production-grade 3-tier web application deployed entirely through the Azure Portal:

- **Frontend** — Azure Blob Storage static website (HTML/CSS/JS)
- **Backend** — Node.js REST API on Azure App Service (Free F1, Linux)
- **Database** — Azure SQL Database (`capstonedb`) on a dedicated SQL Server
- **Secrets** — Azure Key Vault, accessed via App Service Managed Identity (zero hardcoded credentials)
- **Monitoring** — Azure Monitor + Log Analytics Workspace + Alert Rule + Action Group (email + push, no voice call)

## The Core Demonstration

This project's primary purpose is to **prove hands-on competency in three specific things**, in order of importance:

1. **Secure credential handling** — the backend retrieves its database connection string from Key Vault at runtime via Managed Identity. At no point does a password, connection string, or API key appear in `app.js`, `package.json`, App Service configuration, or Git history.
2. **Frontend-to-backend REST communication** — the static frontend calls the backend exclusively over HTTP using `fetch()` against two REST endpoints (`/api/health`, `/api/products`), with CORS explicitly configured rather than left open by accident.
3. **Automated, cost-aware alerting** — a metric alert rule watches the backend for HTTP 5xx errors and notifies via email and push notification (voice call deliberately excluded for cost reasons) when it fires, demonstrating observability without paying for a premium monitoring tier.

## Live Endpoints

| Component | URL |
|---|---|
| Frontend | `https://capstone009bstorage.z8.web.core.windows.net` |
| API Health | `https://app-capstone-009-h6cga4dhbtfeftgb.australiaeast-01.azurewebsites.net/api/health` |
| API Products | `https://app-capstone-009-h6cga4dhbtfeftgb.australiaeast-01.azurewebsites.net/api/products` |

## Architecture

```
Browser
   │  HTTPS
   ▼
Blob Storage ($web container) ── index.html
   │  fetch() → GET /api/products  (REST, CORS-enabled)
   ▼
App Service (app-capstone-009, Node.js 22 LTS, Free F1)
   │  Managed Identity → DefaultAzureCredential
   ▼
Key Vault (kv-capstone-009) ── secret: SqlConnectionString
   │  connection string returned (never logged, never hardcoded)
   ▼
Azure SQL (capstone-sql-009 → capstonedb → Products table)
   │  SELECT id, name, price FROM Products
   ▼
JSON → App Service → Browser

Azure Monitor
   Log Analytics Workspace (law-capstone-009)
   Alert Rule: Http5xx > 5 in 5 min → Action Group
        → Email notification
        → Push notification (voice call intentionally excluded — cost)
```

Diagram source: `architecture/opscloud-009-architecture.svg`

## Resource Inventory

| Resource | Name | Region | Tier |
|---|---|---|---|
| Resource Group | `rg-capstone-opscloud009` | Australia East | — |
| SQL Server | `capstone-sql-009` | Australia East | — |
| SQL Database | `capstonedb` | Australia East | Basic (5 DTU) |
| Key Vault | `kv-capstone-009` | Australia East | Standard, RBAC |
| App Service Plan | `ASP-rgcapstoneopscloud009-b25c` | Australia East | Free F1 |
| App Service | `app-capstone-009` | Australia East | Node 22 LTS, Linux |
| Storage Account | `capstone009bstorage` | Australia East | Standard LRS |
| Log Analytics Workspace | `law-capstone-009` | Australia East | Pay-as-you-go |
| Action Group | `ag-capstone-009` | East US | Email + Push |

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Authentication | Managed Identity (no passwords) | Credentials never appear in code or config — this is the central learning goal of the project |
| Secret storage | Key Vault, RBAC permission model | Centralised, auditable, rotatable without redeploying code |
| App Service → Key Vault role | Secrets User (not Secrets Officer) | Least privilege — app only reads, never manages secrets |
| App Service → SQL role | `db_datareader` (not `db_owner`) | App only queries data; cannot delete/alter if compromised |
| Database network access | **Public endpoint with IP firewall** (not Private Endpoint) | Scope decision — see "Private Endpoint: Planned vs. Delivered" below |
| App Service tier | Free F1 | Zero compute cost for a dev/portfolio workload |
| SQL Database tier | Basic (5 DTU) | $5.39 USD/month, sufficient for demo data |
| Backup redundancy | Locally-redundant (LRS) | Dev environment with reproducible sample data — GRS unnecessary |
| Deployment method | VS Code Azure App Service extension | Reliable `npm install` handling vs. manual ZIP deploy |
| Alert threshold | HTTP 5xx > 5 in 5 minutes | Avoids alert fatigue from single transient errors |
| Alert severity | 1 – Error | Feature-breaking but not full outage (Severity 0) |
| Alert channels | Email + push, no voice call | Voice call carrier charges are a recurring cost with no added signal over email/push for a single-engineer project |

## Private Endpoint: Planned vs. Delivered

The original project plan (carried over from OPS-CLOUD-004, which specifically practiced Private Endpoints) called for `capstonedb` to be placed behind a Private Endpoint, removing it entirely from the public internet, consistent with the zero-trust pattern already demonstrated in that earlier project.

**This was removed from OPS-CLOUD-009's scope during Day 1**, and the database was secured with the public endpoint plus IP-based firewall rules and Managed Identity authentication instead. This was a deliberate trade-off, not an oversight:

- **Cost and complexity vs. learning value already proven.** OPS-CLOUD-004 already demonstrated Private Endpoint + Private DNS Zone competency in isolation. Re-implementing it here would not add a new skill — it would only repeat one already on record, while a Private Endpoint also requires a VNet and Private DNS Zone for App Service to resolve the SQL hostname internally, adding real configuration time to a capstone whose stated focus was credential security, REST communication, and alerting.
- **App Service on the Free F1 tier does not support VNet Integration.** Virtual network integration requires Basic tier or higher on the App Service Plan. Keeping App Service on Free F1 (a deliberate cost decision for this project) and adding a Private Endpoint on SQL would have meant App Service could not actually reach the database privately — the architecture would not have worked end-to-end without upgrading the App Service Plan, which conflicts with the project's cost-minimisation goal.
- **The risk Private Endpoint mitigates was already addressed differently.** The actual threat being defended against — unauthorised database access — is handled here by IP firewall rules restricting access to my known IP plus Azure services, combined with Managed Identity authentication and a least-privilege `db_datareader` role. The database is not anonymously reachable even though it has a public endpoint.

**New learning captured from this trade-off:** Private Endpoint is not a default best practice to apply everywhere — it has a real cost in App Service tier requirements and VNet complexity, and the decision to use it should be driven by the actual sensitivity of the data and the compute tier already committed to, not applied automatically because a prior project used it. This is documented here specifically so the gap between the original plan and the delivered architecture is traceable, not silently dropped.

If this project is revisited at a higher App Service tier (Basic or above) in Phase 2, adding the Private Endpoint back is the natural next iteration and is noted as a backlog item below.

## Problems Encountered & Solutions

**1. SQL Query Editor blocked by firewall**
Azure SQL only allowed Azure-internal traffic by default; my local IP (`202.7.247.186`) wasn't whitelisted. Resolved using the portal's one-click "Allowlist IP" link on the connection error.

**2. SQL service tier defaulted to Hyperscale ($317 USD/month)**
The database creation wizard reset to a Hyperscale Production configuration after switching tabs. Fixed by explicitly reconfiguring Compute + storage to the Basic (5 DTU) tier and re-verifying the cost summary before creating.

**3. `/api/products` failed while `/api/health` succeeded**
The health endpoint worked because it doesn't touch SQL, isolating the fault to the database connection layer specifically. Root cause: Managed Identity was authenticated to Key Vault and held a valid connection string, but SQL Server itself didn't recognise `app-capstone-009` as an authorised user — Key Vault access and SQL-level authorisation are two separate trust relationships, not one. Fixed by setting an Entra ID admin on the SQL Server, then running:
```sql
CREATE USER [app-capstone-009] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-capstone-009];
```

**4. Blob Storage static site not publicly reachable**
Default storage account creation had "Blob anonymous access" disabled, which blocks static website hosting entirely even with the rest of the configuration correct. Enabled it under the Security tab before deployment.

**5. App Service ZIP deployment didn't run `npm install`**
Encountered previously in OPS-CLOUD-005 with `SCM_DO_BUILD_DURING_DEPLOYMENT`. This time, deploying via the VS Code Azure App Service extension handled the build automatically — no SSH workaround needed.

**6. Private Endpoint removed from scope mid-project**
Not a technical failure but a scope decision made on Day 1 — see "Private Endpoint: Planned vs. Delivered" above. Documented separately because it changes the security model from the original plan and needs to be traceable for anyone reviewing this project.

## Testing & Validation

| Test | Result |
|---|---|
| `/api/health` | ✅ Returns `{status: "healthy", region: "Australia East"}` |
| `/api/products` (before SQL fix) | ❌ `{"error":"Failed to fetch products"}` |
| `/api/products` (after `db_datareader` grant) | ✅ Returns 4 products as JSON |
| Frontend → API integration (REST over fetch) | ✅ Products render correctly in browser |
| Credential exposure check | ✅ No password/connection string found in app.js, package.json, or App Service config |
| Alert rule | ✅ Configured, $0.10/month, 0 alerts fired (system healthy) |

## Cost Analysis

| Resource | Monthly Cost (USD) |
|---|---|
| App Service (Free F1) | $0.00 |
| SQL Database (Basic) | $5.39 |
| Key Vault (Standard) | ~$0.00 |
| Blob Storage (LRS) | ~$0.01 |
| Log Analytics Workspace | ~$0.00 (within free 5GB tier) |
| Alert Rule | $0.10 |
| Action Group (Email + Push, no voice) | ~$0.00 |
| **Total (while SQL is active)** | **~$5.50** |
| **Total (after SQL deleted post-demo)** | **~$0.11** |

Voice call notifications were deliberately excluded from the Action Group. Azure Monitor voice calls carry a per-call charge and add no information over email or push for a single-person project — this was a conscious cost trade-off, not a missed feature.

## What I Learned

- 3-tier architecture isolates concerns: presentation, business logic, and data each fail independently and scale independently
- Managed Identity removes credential management from the developer entirely — no rotation, no leaks, no plaintext secrets
- Least privilege must be applied at every layer, not just once: Key Vault role *and* SQL database role both needed scoping down separately
- Key Vault access and SQL-level database authorisation are two distinct trust boundaries — fixing one does not automatically fix the other
- A working health-check endpoint alongside a failing data endpoint is a powerful debugging signal — it isolates the fault to a specific tier before you start reading logs
- Deployment tooling matters: VS Code's Azure extension proved more reliable than manual ZIP upload for Node.js apps on Free tier
- Alert thresholds and notification channels are design decisions, not defaults — too sensitive and alerts get ignored; voice calls add cost without adding signal
- **Private Endpoint is not a default — it's a trade-off.** It requires a compute tier capable of VNet Integration, and applying it automatically because a previous project used it is the wrong reason to add infrastructure. The decision should be driven by data sensitivity and the tier already committed to.

## Skills Demonstrated

Azure SQL Database deployment and DTU sizing · Key Vault RBAC and Secrets User least-privilege scoping · App Service deployment via VS Code extension · System-assigned Managed Identity configuration · SQL Entra ID admin setup and `db_datareader` role assignment · Blob Storage static website hosting · REST API design and frontend-backend integration (Express.js + fetch + CORS) · Azure Monitor, Log Analytics, and metric-based alert rules · Action Group configuration with cost-aware channel selection · Cost-conscious tier selection and trade-off documentation · Production incident debugging methodology · Scope decision-making and traceable documentation of plan changes

## Backlog / Next Iteration

- Re-introduce Private Endpoint on `capstonedb` if App Service is upgraded to Basic tier or above (required for VNet Integration)
- Move Action Group region to match Resource Group region (currently East US vs. Australia East — functional but inconsistent)
- Phase 2: re-automate this entire project via Azure CLI + Bash

---

*Project Owner: Koteswar Rao*
*Phase: 1 — Azure Console (GUI)*
*Next: Phase 2 — Azure CLI + Bash automation*
