# OPS-CLOUD-005 — Secure App Service + Key Vault Integration

> **Phase 1 — Azure Console (GUI)**  
> **Week 3 — Security & Identity**  
> **Status:** ✅ Completed | **Date:** 9 May 2026

---

## Jira Ticket

| Field | Detail |
|-------|--------|
| **Ticket ID** | OPS-CLOUD-005 |
| **Priority** | Critical |
| **Epic** | Azure GUI Mastery — Week 3 Security & Identity |
| **Assigned To** | Koteswar (Cloud Engineer) |

### Scenario

You are onboarding onto a new project at a healthcare company. The existing Node.js web application stores the production database password as a hardcoded string in `server.js` — and that file is committed to a public GitHub repository. The security team has flagged this as a critical vulnerability.

Your job: re-architect the secrets management so the application retrieves its database password from Azure Key Vault at runtime using Managed Identity — with zero passwords stored in code, config files, or environment variables.

### Acceptance Criteria

- Azure Key Vault deployed with a secret (`DatabasePassword`) stored securely
- Azure App Service deployed with System-assigned Managed Identity enabled
- App Service granted **Key Vault Secrets User** RBAC role (read-only — least privilege)
- Environment variable configured using Key Vault Reference syntax — green checkmark confirms resolution
- Application retrieves and displays the secret at runtime — no Key Vault SDK required
- Test: disabling Managed Identity breaks secret retrieval (proves the dependency)
- Zero passwords in application code or configuration files

---

## What I Built

A passwordless secrets management solution connecting Azure App Service to Azure Key Vault via Managed Identity. The Node.js application reads a database password from an environment variable — Azure silently fetches that value from Key Vault at runtime using the app's Managed Identity. No credentials stored anywhere in the application.

| Component | Details |
|-----------|---------|
| Resource Group | RG-OPS-CLOUD-005-Secure-App-KeyVault |
| Key Vault | OPS-CLOUD-005-safelocker |
| Secret | DatabasePassword |
| App Service | app-ops-cloud-005-vm |
| Runtime | Node.js 24 LTS (Linux) |
| Managed Identity | System-assigned |
| RBAC Role | Key Vault Secrets User (read-only) |

---

## Why I Built It

Hardcoded secrets in application code is one of the most common and most critical security vulnerabilities in cloud deployments. It's also one of the most preventable.

This project answers: **how do you give an application access to a secret without the application ever knowing the secret exists in code?**

The answer is Managed Identity + Key Vault References. The application reads `process.env.DB_PASSWORD` — a normal environment variable. Azure intercepts that read, fetches the current secret value from Key Vault using the app's identity, and injects it transparently. The developer never sees the password. The codebase never contains the password.

---

## Architecture

```
Azure Key Vault
OPS-CLOUD-005-safelocker
Secret: DatabasePassword = "P@ssw0rd123!AzureSQL"
         │
         │ RBAC: Key Vault Secrets User
         │ (read-only — least privilege)
         │
         ▼
App Service — Managed Identity
app-ops-cloud-005-vm
│
│ Environment Variable:
│ DB_PASSWORD = @Microsoft.KeyVault(
│   SecretUri=https://OPS-CLOUD-005-safelocker
│             .vault.azure.net/secrets/DatabasePassword/
│ )
│
▼
Node.js Application
const secret = process.env.DB_PASSWORD
// Azure injects the Key Vault value here — no SDK needed
// Output: P@ssw0rd123!AzureSQL ✅
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Key Concepts

### Managed Identity

Azure's implementation of passwordless authentication for services. When App Service needs to authenticate to Key Vault:

1. Azure generates a token for the App Service's identity automatically
2. Token is presented to Key Vault
3. Key Vault checks the RBAC role — allows or denies
4. No password was stored, transmitted, or visible at any point

**Real-world analogy:** Your face is your identity. Security guards recognize your face without you carrying an ID card. If your identity is revoked, they won't let you in — no password to steal.

### Key Vault Reference Syntax

```
@Microsoft.KeyVault(SecretUri=https://VAULT-NAME.vault.azure.net/secrets/SECRET-NAME/)
```

App Service detects the `@Microsoft.KeyVault(` prefix in an environment variable value and intercepts it:
1. Uses Managed Identity to authenticate to Key Vault
2. Fetches the secret value
3. Injects it as the environment variable value
4. App code reads `process.env.DB_PASSWORD` — sees only the password, not the reference string

**Critical — no version number in the URI:**  
`/secrets/DatabasePassword/` (trailing slash) = always fetches **latest version**  
`/secrets/DatabasePassword/abc123...` = locked to that specific old version forever

When secrets rotate, the versionless URI automatically picks up the new value. No code changes. No redeployment.

### RBAC — Principle of Least Privilege

| Role | Can Read Secrets | Can Create/Delete Secrets | Assigned To |
|------|-----------------|--------------------------|-------------|
| Key Vault Secrets User | ✅ Yes | ❌ No | App Service (runtime) |
| Key Vault Secrets Officer | ✅ Yes | ✅ Yes | Admin account (setup only) |

The application only needs to **read** secrets. Giving it write access follows the same logic as giving a cashier the keys to the safe — unnecessary and dangerous if compromised.

---

## Build Steps

### Step 1 — Create Resource Group
- Name: `RG-OPS-CLOUD-005-Secure-App-KeyVault`
- Region: Australia East

### Step 2 — Create Azure Key Vault
- Name: `OPS-CLOUD-005-safelocker` (globally unique)
- Region: Australia East — same as App Service for low latency
- Access model: **Azure RBAC** (not legacy Access Policies)
- Public network access: Enabled (lab — production would use Private Endpoint from OPS-CLOUD-004)

### Step 3 — Assign RBAC Role to Self
Granted own account **Key Vault Secrets Officer** to create secrets during setup.

### Step 4 — Create Secret
- Name: `DatabasePassword`
- Value: `P@ssw0rd123!AzureSQL`
- Content type: text/plain

### Step 5 — Create App Service
- Name: `app-ops-cloud-005-vm`
- Runtime: Node.js 24 LTS — Linux
- Region: Australia East (same as Key Vault — minimises secret retrieval latency)
- Tier: Premium V3 P0V3

### Step 6 — Enable Managed Identity
- App Service → Identity → System assigned → **ON**
- Azure created Object ID: `22fbb868-ba66-46f3-e96a-e723c3bf2af9`
- Identity now exists in Entra ID and can be granted RBAC roles

### Step 7 — Grant RBAC Role to App Service
- Key Vault → Access control (IAM) → Add role assignment
- Role: **Key Vault Secrets User** (read-only — least privilege)
- Assigned to: `app-ops-cloud-005-vm` (Managed Identity)

### Step 8 — Configure Key Vault Reference
- App Service → Environment variables → Application settings
- Name: `DB_PASSWORD`
- Value: `@Microsoft.KeyVault(SecretUri=https://OPS-CLOUD-005-safelocker.vault.azure.net/secrets/DatabasePassword/)`
- Green checkmark ✅ confirms Key Vault Reference resolved successfully

### Step 9 — Deploy Node.js Application

**server.js**
```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
    const secret = process.env.DB_PASSWORD || 'Secret not found';
    res.send(`<h1>OPS-CLOUD-005</h1><p>Secret: ${secret}</p>`);
});

app.listen(PORT);
```

Key line: `process.env.DB_PASSWORD` — reads the environment variable Azure populated from Key Vault. No Key Vault SDK. No credentials in code.

### Step 10 — Troubleshoot: npm install via SSH
Automatic build failed on Free tier with ZIP deployment. Used App Service SSH to manually run `npm install` — installed 69 packages including Express. Startup command set to `npm start`.

---

## Testing & Validation

### Test 1 — Normal Operation ✅
- Managed Identity: ON | RBAC: Granted | KV Reference: Configured
- Result: Secret retrieved — `P@ssw0rd123!AzureSQL` displayed

### Test 2 — Managed Identity Disabled ❌
- Turned Managed Identity OFF → restarted app
- Result: App displayed the **literal Key Vault reference string** instead of the secret value
- Why: Without an identity, App Service cannot authenticate to Key Vault. Azure returns the reference string as a fallback instead of crashing the app.
- Key learning: Managed Identity is the foundation of the entire flow. RBAC permission alone is not enough.
- Remediation: Turned Managed Identity back ON → secret retrieved successfully ✅

---

## Key Decisions & Reasoning

**Why RBAC over Access Policies?**  
RBAC is the modern Microsoft-recommended model. Consistent across all Azure services. More scalable and auditable than per-vault Access Policies which are legacy.

**Why same region for Key Vault and App Service?**  
Cross-region secret retrieval adds 150–250ms latency per fetch. Co-locating in Australia East keeps retrieval fast and avoids egress charges.

**Why no version number in the Secret URI?**  
Versionless URI always fetches the latest secret. When the database password rotates, the app automatically picks up the new value after restart — no code changes, no redeployment.

**Why Key Vault Secrets User and not Secrets Officer for the app?**  
Least privilege. The application only needs to read secrets at runtime. If the App Service is compromised, attackers cannot use its identity to create, modify, or delete secrets.

---

## Problems Encountered & How I Resolved Them

**SCM_DO_BUILD_DURING_DEPLOYMENT did not trigger npm install**  
Setting `SCM_DO_BUILD_DURING_DEPLOYMENT=true` did not automatically run `npm install` on the Free F1 tier with ZIP deployment. Fix: used App Service SSH (Development Tools → SSH) to manually run `npm install` inside `/home/site/wwwroot`.

**Silent failure when Managed Identity disabled**  
Expected the app to crash or throw an error. Instead it displayed the literal `@Microsoft.KeyVault(...)` string — a silent failure that could go unnoticed in production. Production fix: add code to detect unresolved references:
```javascript
if (secret.startsWith('@Microsoft.KeyVault')) {
    throw new Error('Secret not resolved — check Managed Identity and RBAC');
}
```

---

## Production Thinking — What Could Go Wrong

**Managed Identity accidentally disabled**  
App displays literal Key Vault reference string — silent failure. Detection: monitor for `@Microsoft.KeyVault` appearing in application output. Fix: re-enable Managed Identity → restart app.

**RBAC role removed**  
Managed Identity exists but Key Vault returns 403 Forbidden. Same symptom as above. Detection: monitor Azure Activity Log for IAM changes, alert on role assignment deletions.

**Key Vault soft-deleted**  
App fails to retrieve secrets. Protection: Key Vault soft-delete is enabled by default (90-day recovery window). Enable purge protection to prevent permanent deletion. Recovery: restore from soft-delete state.

**Secret rotation**  
Update secret value in Key Vault (new version created). App automatically fetches new version on next retrieval because URI has no version number. Restart app to pick up immediately. Zero downtime with deployment slots.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| Managed Identity = passwordless auth | App Service authenticated to Key Vault with no stored credentials |
| RBAC principle of least privilege | Secrets User (read-only) assigned to app — not Secrets Officer |
| PaaS = no infrastructure management | Key Vault and App Service fully managed — no VMs to patch |
| Same region for low latency | Both resources in Australia East |
| Secrets never in code | server.js contains no passwords — only reads process.env.DB_PASSWORD |
| Audit logs for compliance | Key Vault logs every secret access with timestamp and identity |
| Defense in depth | Identity + RBAC + encryption at rest + encryption in transit |

---

## Resource Cleanup

1. Azure Portal → Resource Groups
2. Click `RG-OPS-CLOUD-005-Secure-App-KeyVault`
3. Delete resource group — cascades to remove all child resources

Resources removed: Key Vault, Secret, App Service, App Service Plan, Managed Identity.

> ⚠️ Always delete the entire Resource Group. Deleting only the App Service but leaving the App Service Plan continues to incur charges.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-005 | Phase 1 Console*  
*Next: [OPS-CLOUD-005b — Identity & Access Management](../OPS-CLOUD-005b-IAM-Entra-RBAC/README.md)*
