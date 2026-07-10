# OPS-CLOUD-P2-002 — Automate Blob Storage Static Site

**Phase:** 2 — Azure CLI + Bash Automation
**Status:** ✅ Complete
**Date:** 10–11 July 2026

---

## Jira Ticket

**OPS-CLOUD-P2-002 : Automate Blob Storage Static Site**
**Sprint:** Week 1 — Compute & Storage Automation
**Type:** Infrastructure Automation

### Problem Statement / Scenario

A company needs a landing page for an internal tool. The content is pure
static HTML/CSS with no server-side logic. The naive approach — spinning
up a VM and installing a web server (as in OPS-CLOUD-P2-001) — means
paying for compute 24/7, patching an OS, and maintaining a web server,
all just to serve files that never change based on user input.

**What I'm solving for:**
- Host a static webpage reachable by a public URL
- Avoid the cost and operational overhead of running a VM for content
  that doesn't need one
- Make the deployment repeatable via CLI/script, not manual Portal
  clicks, so it can be re-run or handed to another engineer without
  re-doing 15–30 minutes of manual configuration each time
- Keep cost proportional to actual traffic/criticality (Hot tier +
  LRS for this low-traffic, non-critical use case)

### Requirements
1. Resource Group created via CLI
2. Storage Account created via CLI (`Standard_LRS`)
3. Static website hosting enabled (property update, auto-creates `$web`)
4. `index.html` uploaded to `$web`
5. Public endpoint URL printed at the end of the script
6. Script safely re-runnable (idempotent where the tooling allows)

---

## What I Built

A bash script (`deploy-blob-static-site.sh`) that provisions a fully working
static website on Azure using Blob Storage — no VM, no VNet, no NSG. The
script:

1. Creates a Resource Group
2. Creates a Storage Account (`Standard_LRS`, `StorageV2`)
3. Enables static website hosting (a property update, not a new resource)
4. Uploads `index.html` into the auto-created `$web` container
5. Prints the live public site URL

**Live endpoint:** `https://p2mystorage1657.z8.web.core.windows.net/`

---

## Why I Built It This Way

**PaaS over IaaS for static content.**
A static landing page has no server-side logic — no reason to run and
maintain a VM (OS patching, Apache config, NSGs, uptime) just to serve
HTML/CSS. Blob Storage static website hosting removes the entire compute
and networking layer: Azure handles replication, scaling, and serving.
This is the direct opposite dependency chain of P2-001 (RG → VNet → NIC →
VM) — here there's nothing to build below the storage account.

**Time savings.**
Manually configuring this in the Azure Portal (storage account creation,
static website toggle, container upload, endpoint lookup) takes roughly
15–30 minutes depending on how familiar you are with the console. The
script does the same work in under 2 minutes and is fully repeatable —
this matters for a company that wants to redeploy or replicate the same
site (e.g. dev/staging/prod) without re-doing manual clicks each time.

**Cost target: near-zero for a low-traffic internal site.**
No compute to pay for 24/7, no OS licensing, no patching labor. This
directly serves a company that doesn't want to spend money on VM
provisioning or maintenance just to host a static page.

**SKU / access tier decisions.**
- **Access tier: Hot** — chosen because this file is expected to be read
  regularly by the public. Hot tier optimizes for frequent access at the
  cost of slightly higher storage price per GB (vs. Cool/Archive, which
  are cheaper to store but expensive to read).
- **Redundancy: Standard_LRS** — chosen because this is a low-traffic,
  non-critical internal page with no backup/disaster-recovery
  requirement. LRS keeps 3 copies within a single datacenter, which is
  sufficient here.
  - **Production note:** if this were a business-critical site, GRS or
    GZRS would be the better choice — both replicate data to a second,
    geographically distant region (in addition to the 3 local copies),
    protecting against a full regional outage. That durability comes at
    a higher cost, which is why it wasn't justified for this project's
    scope.

**Reusability.**
The script is portable with minimal changes:
- Within the **same subscription**, only resource names need to change
  (to avoid collisions with existing resources).
- Across a **different subscription**, resource group and general naming
  can stay identical — the only hard constraint is the storage account
  name, which must be globally unique across *all* of Azure, not just
  within one subscription.

---

## Problems Encountered, Fixes, and Why

### 1. CLI API version mismatch (`InvalidApiVersionParameter`)
**What happened:** `az storage account update` failed, citing an API
version the resource provider didn't recognize.
**Root cause:** The installed Azure CLI (`2.73.0`) was out of date and
was requesting a deprecated API version.
**Fix:** `az upgrade` (via Homebrew) → CLI updated to `2.88.0`.
**Learning:** CLI tooling drifts out of date silently. Production teams
typically pin/version-lock their CLI in CI pipelines specifically to
avoid this kind of mid-deployment surprise.

### 2. Second API version mismatch after upgrading
**What happened:** Even after upgrading, the same command failed again —
this time requesting an API version *newer* than what the provider
actually supported.
**Root cause:** A stale local CLI cache/metadata mismatch after the
upgrade.
**Fix:** `az cache purge`, followed by `az provider register --namespace
Microsoft.Storage` to re-confirm provider registration. When the issue
persisted, worked around it using the generic ARM command
(`az resource update --api-version <known-good-version>`) instead of the
storage-specific CLI command, explicitly pinning a version the provider
listed as supported.
**Learning:** When a specific `az` subcommand misbehaves, the generic
`az resource` commands are a reliable fallback since they let you pin an
exact, provider-confirmed API version.

### 3. `az role assignment create --assignee <email>` failed to resolve identity
**What happened:** Attempting to grant myself the "Storage Blob Data
Contributor" role (needed for `--auth-mode login`) failed with *"Cannot
find user or service principal in graph database."*
**Root cause:** Microsoft/Gmail-based (MSA) accounts don't always resolve
cleanly via email lookup against Azure AD Graph, unlike native
work/school Azure AD accounts.
**Fix:** Fell back to `--auth-mode key` for the upload step to stay
unblocked and complete the deployment on schedule.
**Learning / follow-up:** The correct production fix is to use
`--assignee-object-id` (from `az ad signed-in-user show --query id -o
tsv`) instead of `--assignee <email>`. This is intentionally left as a
known gap to revisit properly during Week 3 (Service Principal + RBAC),
where identity-based access is the core topic.

### 4. Incorrect assumption: `allowBlobPublicAccess` needed to be `true`
**What happened:** After seeing `"allowBlobPublicAccess": false` in the
storage account JSON output, I assumed the static site would be blocked
from public access and manually patched it to `true`.
**What was actually true (verified via Microsoft Learn docs):** Static
website hosting is served through a **separate endpoint**
(`*.z8.web.core.windows.net`), independent of the standard blob endpoint
(`*.blob.core.windows.net`). Microsoft's documentation confirms
disabling public access on a storage account does not affect static
websites hosted in that account — the static site endpoint always
serves `$web` content anonymously by design, regardless of the
account-level `allowBlobPublicAccess` setting.
**Fix:** None needed — the site was live and public the entire time,
even with the setting at `false`.
**Learning:** Don't assume a setting applies globally just because it
sounds related — verify against source documentation. This was a wasted
troubleshooting step caused by an incorrect assumption, not an actual
bug.

### 5. Empty file execution / unsaved editor state
**What happened:** Ran the script and got no output at all.
**Root cause:** The script had been edited in VS Code but never saved —
the terminal was executing a stale, mostly-empty version of the file
from disk.
**Fix:** Saved the file (`Cmd+S`), confirmed contents with `cat`, re-ran.
**Learning:** The VS Code editor pane and the integrated terminal read
from different states until a save happens — editing is not the same as
persisting to disk.

---

## Auth-Mode Decision (Key vs. Login vs. Key Vault)

The script currently uses `--auth-mode key` for the upload step as a
pragmatic workaround for problem #3 above. This is **not** the ideal
production pattern:

- **Storage account keys** are master credentials — full read/write/
  delete access to the *entire* account, not scoped to one container.
  They don't expire automatically and require manual rotation if leaked.
- **The stronger production pattern** is identity-based auth
  (`--auth-mode login`, or a Managed Identity if running from a
  pipeline/App Service) — this avoids a long-lived secret existing at
  all.
- **Key Vault** is a legitimate *fallback* if a key must be used — it
  centralizes rotation, adds audit logging, and controls who/what can
  retrieve the key. But it's a mitigation for using a key, not a
  replacement for fixing the underlying identity/RBAC problem.

**Follow-up for a future revision:** resolve the RBAC assignee lookup
issue (via `--assignee-object-id`) and switch the script back to
`--auth-mode login`, removing the key dependency entirely.

---

## What Could Go Wrong (Production Thinking)

**Q: If this script's key-based auth call were committed to a shared
repo or CI pipeline, what's the actual exposure?**
Anyone with access to that pipeline config or repo history gets
full read/write/delete access to every container in the storage
account — not just `$web`. There's no way to scope a storage account key
to a single container or action. This is exactly why the identity-based
approach (`--auth-mode login` / Managed Identity) is the correct
long-term fix, not just a nice-to-have.

---

## Deliverables

- `deploy-blob-static-site.sh` — full automation script
- `index.html` — static landing page
- `README.md` — this file
- Portal screenshots — RG, storage account, `$web` container, static
  website config, live site (incognito-verified)
