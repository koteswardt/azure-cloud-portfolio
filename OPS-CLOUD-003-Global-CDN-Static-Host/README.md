# OPS-CLOUD-003 — Global CDN Static Host

> **Phase 1 — Azure Console (GUI)**  
> **Week 2 — PaaS & Managed Services**  
> **Status:** ✅ Completed | **Date:** 20 April 2026

---

## What I Built

A globally distributed static website using Azure Blob Storage as the origin and Azure Front Door as the Content Delivery Network (CDN). Website files stored in a single region (Central India) are cached at edge locations worldwide — a user in Sydney receives the site from a Sydney edge cache, not from India.

| Layer | Service | Role |
|-------|---------|------|
| Origin | Azure Blob Storage (staticnewhost) | Stores index.html — single source of truth |
| Delivery | Azure Front Door Standard | Caches and delivers globally via edge nodes |

---

## Why I Built It

Hosting a website in one region is the naive solution. It works — but only well for users near that region. A user in Australia hitting a server in Central India experiences real network round-trip delay on every request.

This project answers a practical question: **how do you serve a website fast to users anywhere in the world without deploying servers in every region?**

The answer is a CDN. One origin. Global edge caches. Users always hit the nearest cache.

---

## Architecture

```
User Request Flow
─────────────────────────────────────────────────────────

First request (cache empty):
User (Sydney) → Front Door Edge (Sydney) → Cache MISS
             → Fetch from Blob Storage (Central India)
             → Cache file at Sydney edge
             → Serve to user

All subsequent requests:
User (Sydney) → Front Door Edge (Sydney) → Cache HIT
             → Serve immediately (no trip to India)

─────────────────────────────────────────────────────────

Architecture:

Internet
   │
   ▼
Azure Front Door Standard (Global)
   Endpoint: ops-cloud-003-cdn-a3adgub4hrc7eraw.z01.azurefd.net
   Caching: Enabled | Query String: Ignore
   │
   ▼ (cache miss only)
Azure Blob Storage — staticnewhost (Central India)
   Static Website Endpoint: staticnewhost.z29.web.core.windows.net
   Container: $web
   File: index.html (Hot tier)
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Key Concept: Edge Locations vs Regions

| Concept | What It Is | Cost |
|---------|-----------|------|
| Region | Full data centre — servers, storage, compute | Expensive |
| Edge Location | Caching server in a major city — stores copies only | Cheap |

For a static website, deploying servers in every region is unnecessary and expensive. CDN edge locations give you global performance at a fraction of the cost — you pay for one origin and caching, not for servers in 20 cities.

---

## Key Concept: Two Blob Storage Endpoints

Blob Storage exposes two completely different URLs. Choosing the wrong one breaks everything:

| Endpoint Type | URL Format | Behaviour |
|--------------|-----------|-----------|
| Static Website | `accountname.z29.web.core.windows.net` | Renders HTML as a webpage. Handles 404 pages. **Correct for Front Door.** |
| Raw Blob | `accountname.blob.core.windows.net` | Serves files as direct downloads. No web rendering. **Wrong — prompts file download instead of showing the page.** |

> ⚠️ When configuring the Front Door origin, Origin Type must be set to **Storage (Static website)** — not plain Storage.

---

## Build Steps

### Step 1 — Create Storage Account

| Configuration | Value |
|--------------|-------|
| Storage Account Name | staticnewhost |
| Resource Group | RG-OPS-CLOUD-003-Global-CDN-Static-Host |
| Region | Central India |
| Performance | Standard — general-purpose v2 |
| Redundancy | LRS (Locally-redundant storage) |

### Step 2 — Apply Tags

| Tag | Value |
|-----|-------|
| Project | OPS-CLOUD-003 |
| Environment | dev |
| Owner | kotesh |
| service | blob-Hot |

### Step 3 — Enable Static Website Hosting & Upload

Enabled Static website hosting on the Storage Account. Azure automatically created two containers:

| Container | Purpose |
|-----------|---------|
| `$web` | Public folder — upload HTML/CSS/JS here |
| `$logs` | Azure stores traffic and access logs here |

Uploaded `index.html` to `$web`. File automatically assigned **Hot (Inferred)** access tier — correct for a publicly visited website.

### Step 4 — Register Microsoft.Cdn Resource Provider

Before creating Front Door, the `Microsoft.Cdn` resource provider required manual registration:

- Subscriptions → Resource providers → Search `Microsoft.Cdn` → Register
- Status changes: `NotRegistered` → `Registering` → `Registered` (1–2 minutes)
- No cost for registration — billing only starts when Front Door resources are deployed

> 💡 This is a common first-time friction point. In production, platform teams pre-register all required resource providers at subscription setup time to avoid deployment failures.

### Step 5 — Create Azure Front Door Profile

| Field | Value & Reasoning |
|-------|------------------|
| Profile Name | ops-cloud-003-fd-profile |
| Tier | Standard — content delivery optimised. Premium adds WAF/DDoS — unnecessary for a static site. |
| Endpoint Name | ops-cloud-003-cdn |
| Endpoint Hostname | ops-cloud-003-cdn-a3adgub4hrc7eraw.z01.azurefd.net |
| Origin Type | **Storage (Static website)** — NOT plain Storage |
| Origin Host Name | staticnewhost.z29.web.core.windows.net |
| Caching | Enabled — without caching, Front Door is just a proxy with no latency benefit |
| Query String Caching | Ignore Query String — static content is identical regardless of URL parameters |

### Step 6 — Verify Deployment

After deployment, waited 15–20 minutes for global propagation to all edge nodes. "Page not found" immediately after deployment was expected — resolved automatically after propagation completed.

- Status: Active
- Location: Global (Front Door is not region-specific)
- Endpoint: Provision succeeded + Enabled

### Step 7 — Live Verification

Site confirmed live via HTTPS on the Front Door endpoint URL. Managed TLS certificate automatically provisioned by Azure — no manual certificate configuration required.

---

## Key Decisions & Reasoning

**Why Standard tier over Premium?**  
Premium Front Door adds WAF bot protection and DDoS rules — necessary for production apps handling user data. For a static site serving only HTML, those features add ~2x cost with zero benefit.

**Why Ignore Query String caching?**  
Static site content is identical regardless of URL parameters. Using "Use Query String" would create thousands of separate cache entries for the same file — wasting edge cache capacity and causing more cache misses.

**Why LRS redundancy?**  
Lab environment — 3 copies within one data centre is sufficient for testing. Production would require ZRS (protect against zone failure) or GRS (protect against full regional outage).

**Why Central India as origin region?**  
Demonstrates the core CDN value proposition — origin is far from Australian users, making the latency improvement from edge caching highly visible and measurable.

---

## Problems Encountered & How I Resolved Them

**Microsoft.Cdn resource provider not registered**  
Front Door creation failed until `Microsoft.Cdn` was manually registered under Subscriptions → Resource providers. New Azure subscriptions do not auto-register every service. One-time fix per subscription.

**"Page not found" immediately after Front Door deployment**  
Expected behaviour — Front Door takes 15–20 minutes to propagate configuration to all global edge nodes. Waited and the site appeared automatically. No action required.

**Plain Storage vs Static Website origin confusion**  
Initially selected plain "Storage" as origin type. Front Door pointed to the raw blob endpoint which serves files as downloads, not rendered HTML. Fixed by selecting "Storage (Static website)" which points to the web-serving endpoint.

---

## Production Thinking — What Could Go Wrong

**LRS origin goes down**  
LRS keeps 3 copies within one data centre. If that data centre goes offline, all copies fail simultaneously. Front Door detects the origin as unhealthy via health probes but with only one origin configured, it has no failover destination. Cached content serves briefly until TTL expires, then the site returns errors globally.

Production fix: upgrade to GRS storage AND configure a second origin in Front Door pointing to the failover region.

**Cache miss causing slow load for a specific region**  
If Sydney users report slow loads but London users are fine, the Sydney edge cache is empty or expired. Front Door fetches from Central India on every Sydney request — accumulating ~141ms per asset. Fix: configure explicit TTL rules in Front Door (HTML: 1 hour, images/CSS: 7 days).

**Leaving Front Door running after lab**  
Unlike a VM which can be deallocated, Front Door has no stop state — it is either running (billing) or deleted. Always delete the entire Resource Group after lab work.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| Edge Locations = CDN caching points | Front Door cached index.html at global edge nodes |
| Hot Tier = frequently accessed files | $web container auto-assigned Hot (Inferred) |
| Region = geographic placement for latency | Central India origin without CDN = high latency for global users |
| PaaS = no OS management | No VM, no web server, no patching — only the HTML file requires attention |
| Resource Groups as cost boundaries | Single delete removes all resources — no orphaned billing |
| Tags for cost management | Project, Environment, Owner, service tags applied |

---

## Resource Cleanup

Deleted `RG-OPS-CLOUD-003-Global-CDN-Static-Host` after documentation captured. Cascades to remove Front Door profile, Storage Account, $web container, index.html, $logs container, and all associated resources.

> ⚠️ Front Door has no stop state — always delete the Resource Group. Deleting only Front Door but leaving the Storage Account still incurs storage charges.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-003 | Phase 1 Console*  
*Next: [OPS-CLOUD-004 — Azure Key Vault + Private Endpoint](../OPS-CLOUD-004-KeyVault-Private-Endpoint/README.md)*
