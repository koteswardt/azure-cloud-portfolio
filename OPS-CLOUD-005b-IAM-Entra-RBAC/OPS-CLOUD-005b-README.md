# OPS-CLOUD-005b — Identity & Access Management (IAM)

> **Phase 1 — Azure Console (GUI)**  
> **Week 3 — Security & Identity**  
> **Status:** ✅ Completed | **Date:** May 2026

---

## Jira Ticket

| Field | Detail |
|-------|--------|
| **Ticket ID** | OPS-CLOUD-005b |
| **Priority** | High |
| **Epic** | Azure GUI Mastery — Week 3 Security & Identity |
| **Assigned To** | Koteswar (Cloud Engineer) |

### Scenario

A new project is kicking off at a fintech company. Three engineers are joining the team — a junior developer, a senior engineer, and an external auditor. The platform team needs to set up Azure access correctly from day one.

Your job: create the users in Microsoft Entra ID, assign them to the correct RBAC roles at the correct scope, and prove that each person can only do what their role permits — and nothing more.

### Acceptance Criteria

- Users created in Microsoft Entra ID
- Correct RBAC roles assigned at Resource Group scope (not subscription — least privilege)
- Junior developer: **Reader** — can view, cannot modify
- Senior engineer: **Contributor** — can create and manage resources, cannot assign roles
- Prove boundaries: junior developer attempting to create a resource returns **403 Forbidden**
- Prove Contributor cannot assign roles to others
- Document the two-layer model: Entra ID (authentication) vs RBAC (authorization)

---

## What I Built

A structured Identity and Access Management setup demonstrating the two-layer Azure security model — Microsoft Entra ID for identity and Azure RBAC for resource permissions. Users created, roles assigned at the correct scope, and access boundaries proven through real portal testing.

---

## Why I Built It

IAM is tested heavily on AZ-104 and comes up in every cloud engineering interview. But more importantly — every Azure project involves access control decisions. Getting this wrong in production means either over-permissioned accounts (security risk) or under-permissioned engineers (operational friction).

This project answers: **how do you give people exactly the access they need — and nothing more?**

---

## The Two-Layer Model

Most engineers confuse these two systems. They are separate and both are required:

| Layer | System | Question It Answers | Example |
|-------|--------|--------------------|---------| 
| Identity Plane | Microsoft Entra ID | Who are you? (Authentication) | junior.dev logs in with password + MFA |
| Resource Plane | Azure RBAC | What can you do? (Authorization) | junior.dev can only view resources in RG-IAM-Lab |

**A user can exist in Entra ID with zero Azure access.** Entra ID proves identity. RBAC grants permissions. Both required — missing either one means no access.

---

## The Four Elements of Every RBAC Decision

Every access control decision in Azure resolves to these four elements:

| Element | Question | Example |
|---------|----------|---------|
| **Security Principal** | WHO needs access? | junior.dev user account |
| **Role Definition** | WHAT actions are allowed? | Reader (view only) |
| **Scope** | WHERE does the permission apply? | RG-OPS-CLOUD-005b-IAM-Lab only |
| **Role Assignment** | HOW are they connected? | The act of assigning Reader to junior.dev at that RG |

---

## Core Roles — Know These Three

| Role | Read | Create/Modify | Delete | Assign Roles | Typical User |
|------|------|--------------|--------|-------------|-------------|
| **Reader** | ✅ | ❌ | ❌ | ❌ | Auditors, junior devs, stakeholders |
| **Contributor** | ✅ | ✅ | ✅ | ❌ | Developers, engineers |
| **Owner** | ✅ | ✅ | ✅ | ✅ | Project leads, admins |

**Critical rule:** Contributor **cannot** assign roles to others. Only Owner (or User Access Administrator) can change IAM permissions. This prevents privilege escalation — even a compromised Contributor account cannot promote itself to Owner.

---

## Understanding Scope — Where the Permission Applies

Azure has four scope levels in a hierarchy. Permissions flow **downward only**:

```
Management Group  (widest — multiple subscriptions)
       │
       ▼
  Subscription  (all resource groups)
       │
       ▼
 Resource Group  (all resources inside)  ← correct scope for most engineers
       │
       ▼
   Resource  (one specific resource — narrowest)
```

**Downward inheritance:** Assign Contributor at Subscription level → user has Contributor on ALL resource groups and ALL resources in that subscription. Too broad for most engineers.

**No upward bleeding:** Assign Reader at Resource Group level → user can only see that RG. Cannot see other RGs. Cannot see the subscription view.

**The blast radius principle:** The narrower the scope and lower the role, the smaller the damage if that account is compromised. Always assign the minimum that allows the work to get done.

---

## Build Steps

### Step 1 — Create Resource Group
- Name: `RG-OPS-CLOUD-005b-IAM-Lab`
- Region: Australia East

### Step 2 — Create Users in Entra ID
- Navigate: Microsoft Entra ID → Users → New user
- Created: `junior.dev@domain.onmicrosoft.com`
- Created: `senior.eng@domain.onmicrosoft.com`

### Step 3 — Assign RBAC Roles at Resource Group Scope
- Navigate: Resource Group → Access control (IAM) → Add role assignment
- `junior.dev` → **Reader** at RG-OPS-CLOUD-005b-IAM-Lab
- `senior.eng` → **Contributor** at RG-OPS-CLOUD-005b-IAM-Lab

### Step 4 — Test Access Boundaries

| Test | User | Action | Result | Proves |
|------|------|--------|--------|--------|
| View resources | junior.dev | Browse resource group | ✅ Allowed | Reader can view |
| Create resource | junior.dev | Try to create Storage Account | ❌ 403 Forbidden | Reader cannot modify |
| Create resource | senior.eng | Create Storage Account | ✅ Allowed | Contributor can create |
| Assign role | senior.eng | Try to add a role assignment | ❌ Blocked | Contributor cannot manage IAM |

> 💡 The 403 error message IS your proof. Screenshot it — it is evidence that RBAC is working correctly.

---

## RBAC Best Practices

### Assign Roles to Groups, Not Individuals

| Approach | New developer joins | Developer leaves | Audit clarity |
|----------|--------------------|-----------------|--------------| 
| Individual assignments | Manually assign role — easy to forget | Manually remove — easy to forget | Hard — 20 individual names in IAM |
| **Group-based (recommended)** | Add to group — role inherited | Remove from group — access revoked instantly | Easy — one group name in IAM |

### Least Privilege at Narrowest Scope

- Developer working on Project A only → assign at Project A's Resource Group, not the subscription
- CI/CD pipeline deploying to one storage account → assign Storage Blob Data Contributor at that specific resource only
- Monitoring tool reading all resources → Reader at Subscription level (legitimate broad scope)

### Never Give Owner to Automation

CI/CD pipelines and scripts should never have Owner. If compromised, an attacker with Owner can assign themselves Owner on your subscription — permanent backdoor. Use Contributor at minimum required scope for automation — always.

---

## How Azure Checks Access on Every Request

Every action in Azure triggers this invisible check in milliseconds:

```
1. Authentication  → Entra ID verifies identity (password + MFA)
2. Token issued    → Lists all user's group memberships
3. Authorization   → RBAC checks token against role assignments at requested scope
4. Decision        → Match found → Allow / No match → 403 Forbidden
5. Audit           → Request logged in Azure Activity Log (allowed or denied)
```

---

## Production Thinking — What Could Go Wrong

**Over-permissioning — giving everyone Contributor at subscription level**  
Blast radius: if any account is compromised or makes a mistake, the damage affects your entire Azure estate — all resource groups, all resources. Fix: always scope to the minimum resource group needed.

**The privilege escalation attack**  
If Contributor included role assignment rights: attacker gains Contributor credentials → assigns Owner to a new account they control → permanent backdoor even after the original account is disabled. Azure prevents this by separating resource management (Contributor) from access management (Owner).

**Individual role assignments at scale**  
10 developers assigned individually. One leaves — someone forgets to remove their role assignment. They retain access for months. Fix: group-based RBAC. Remove from group = instant access revocation across all resources.

---

## Key Difference: Managed Identity vs Service Principal

Both are non-human identities. Frequently confused in interviews:

| | Managed Identity | Service Principal |
|-|-----------------|-------------------|
| **Password** | None — Azure manages everything | You manage credentials |
| **Rotation** | Automatic | Manual |
| **Use case** | Azure services talking to Azure services | External apps, CI/CD pipelines |
| **Example** | App Service reading Key Vault (OPS-CLOUD-005) | GitHub Actions deploying to Azure |

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| Entra ID = authentication only | Users created in Entra ID — no Azure access until RBAC assigned |
| RBAC = authorization | Reader and Contributor assigned at Resource Group scope |
| Scope controls blast radius | Permissions at RG level only — not subscription |
| Least privilege | Reader for junior dev, Contributor for senior eng, never Owner for automation |
| Group-based RBAC | Best practice documented — scale without individual assignments |
| Contributor cannot assign roles | Proven through portal test — prevents privilege escalation |

---

## Resource Cleanup

Delete `RG-OPS-CLOUD-005b-IAM-Lab` from the portal — cascades to remove all child resources.

Remove test users from Entra ID: Microsoft Entra ID → Users → select user → Delete.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-005b | Phase 1 Console*  
*Next: [OPS-CLOUD-006 — Cloud Watchtower](../OPS-CLOUD-006-Cloud-Watchtower/README.md)*
