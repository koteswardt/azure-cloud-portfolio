# OPS-CLOUD-007 — Load-Balanced Fleet

> **Phase 1 — Azure Console (GUI)**  
> **Week 4 — High Availability**  
> **Status:** ✅ Completed | **Date:** 27 May 2026

---

## Jira Ticket

| Field | Detail |
|-------|--------|
| **Ticket ID** | OPS-CLOUD-007 |
| **Priority** | Critical |
| **Epic** | Azure GUI Mastery — Week 4 High Availability |
| **Assigned To** | Koteswar (Cloud Engineer) |

### Scenario

The incident manager has raised a critical concern after last week's outage: the company's legacy web server is a single point of failure. When it went down, bringing it back took 45 minutes — and every user was impacted for the entire window. The business cannot accept that risk again.

Your job: redesign the web tier to eliminate the single point of failure. Deploy two identical web servers across separate physical hardware, place a Load Balancer in front of them, and **prove** that taking one server offline has zero impact on users.

### Acceptance Criteria

- Two Ubuntu VMs deployed in an Availability Set across separate fault domains
- Standard Load Balancer distributing traffic across both VMs
- Nginx installed on both VMs serving distinct pages (VM1 vs VM2 — so failover is visually provable)
- Health probe configured — TCP port 80, 15 second interval
- Failover test: stop VM2, confirm browser still serves VM1 within 15–20 seconds
- Screenshot proving traffic continues after one VM goes offline

---

## What I Built

A high availability web tier using an Azure Availability Set and Standard Load Balancer. Two Ubuntu VMs on separate physical racks, sitting behind a single public IP — users always reach a healthy server even if one VM goes down completely.

| Resource | Name | Configuration |
|----------|------|--------------|
| Resource Group | RG-OPS-CLOUD-007-Load-Balanced-Fleet | Australia East |
| Availability Set | OPS-CLOUD-007-Availability-Set | Fault domains: 2, Update domains: 2 |
| Virtual Network | OPS-CLOUD-007-VNet | 10.0.0.0/16 |
| VM1 | OPS-CLOUD-007-Vm1 | Ubuntu 24.04, Fault Domain 0 |
| VM2 | OPS-CLOUD-007-Vm2 | Ubuntu 24.04, Fault Domain 1 |
| Load Balancer | OPS-CLOUD-007-LB | Standard SKU, Public, Regional |
| Frontend IP | OPS-CLOUD-007-LB-Frontend | 4.197.120.46 — Static |
| Health Probe | OPS-CLOUD-007-Health-Probe | TCP port 80, interval 15s |
| LB Rule | OPS-CLOUD-007-LB-Rule | Port 80 → Port 80 |

---

## Why I Built It

A single server is a single point of failure. The moment it goes down — hardware fault, OS crash, Azure maintenance — all users are impacted. High availability architecture distributes that risk across multiple machines.

This project answers: **how do you design a system that survives a server failure with zero user impact?**

The answer is Availability Sets + Load Balancer. Azure guarantees the VMs are on separate physical racks. The Load Balancer detects failures automatically and reroutes traffic — no human intervention required.

---

## Architecture

```
                     INTERNET
                         │
                    Port 80 (HTTP)
                         │
              ┌──────────────────────┐
              │   OPS-CLOUD-007-LB   │
              │  Frontend IP:        │
              │  4.197.120.46        │
              │  Standard SKU        │
              └──────────────────────┘
               /                    \
         Health Probe           Health Probe
         TCP:80                  TCP:80
              │                    │
              ▼                    ▼
  ┌─────────────────┐   ┌─────────────────┐
  │ OPS-CLOUD-007   │   │ OPS-CLOUD-007   │
  │ Vm1             │   │ Vm2             │
  │ 10.0.0.4        │   │ 10.0.0.5        │
  │ Fault Domain: 0 │   │ Fault Domain: 1 │
  │ Nginx: port 80  │   │ Nginx: port 80  │
  └─────────────────┘   └─────────────────┘
           \                    /
            \                  /
      ┌──────────────────────────────┐
      │  OPS-CLOUD-007-VNet          │
      │  Subnet: 10.0.0.0/24         │
      │  NSG: HTTP(80) + SSH(22)     │
      └──────────────────────────────┘
                     │
      ┌──────────────────────────────┐
      │  Availability Set            │
      │  Fault Domains: 2            │
      │  Update Domains: 2           │
      └──────────────────────────────┘
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Key Concepts

### Availability Set — Why It Matters

An Availability Set is a logical grouping that tells Azure to place VMs on **separate physical hardware**:

| Domain Type | What It Protects Against | How |
|-------------|-------------------------|-----|
| **Fault Domain** | Hardware rack failure | VMs on separate racks with separate power + network |
| **Update Domain** | Azure planned maintenance | Azure never reboots both VMs in the same maintenance window |

VM1 on Fault Domain 0, VM2 on Fault Domain 1 — a rack failure only takes down one VM. The other keeps serving traffic.

> ⚠️ Critical build rule: Availability Set must be created **before** the VMs. VMs must be placed in the Availability Set at creation time — this cannot be changed afterwards. Azure's fabric controller assigns physical placement at provisioning time.

### Load Balancer — The Four Components

Every Standard Load Balancer requires all four components linked together:

| Component | Purpose | This Project |
|-----------|---------|-------------|
| Frontend IP | Single entry point for users | 4.197.120.46 (Static, Public) |
| Backend Pool | The VMs receiving traffic | VM1 (10.0.0.4) + VM2 (10.0.0.5) |
| Health Probe | Detects unhealthy VMs | TCP port 80, every 15 seconds |
| LB Rule | Links frontend to backend | Port 80 → Port 80 |

If any one of these four is missing or misconfigured — no traffic flows.

### Health Probe — The LB's Only Awareness

The Load Balancer has no built-in knowledge of whether your application is healthy. It only knows what the health probe tells it.

- Probe sends TCP SYN to port 80 every 15 seconds
- **Two consecutive failures** → VM marked unhealthy → LB stops sending traffic
- Nginx stopped but VM running → probe fails → LB correctly removes VM from rotation
- VM restarted → probe passes → LB adds VM back automatically

### Standard LB — Why Not Basic?

| | Standard SKU | Basic SKU |
|-|-------------|----------|
| SLA | 99.99% | No SLA |
| Security | Secure by default — NSG required | Allows all traffic by default |
| Health probes | HTTP, HTTPS, TCP | TCP only |
| Status | Current — actively developed | **Being retired by Microsoft** |

Always use Standard. Basic SKU is being retired and is a security risk (allows all inbound traffic by default).

### Layer 4 vs Layer 7

Standard Load Balancer operates at **Layer 4 (TCP/UDP)**:
- Forwards packets based on IP and port
- Cannot see HTTP content
- Cannot terminate SSL — no visibility into encrypted traffic
- Cannot route based on URL path or hostname

For HTTPS termination and URL-based routing → use **Application Gateway** (Layer 7). Port 80 was used in this lab to focus on HA concepts without certificate management complexity.

---

## Build Steps

### Step 1 — Create Resource Group
- Name: `RG-OPS-CLOUD-007-Load-Balanced-Fleet`
- Region: Australia East

### Step 2 — Create Availability Set *(must be first)*
- Name: `OPS-CLOUD-007-Availability-Set`
- Fault domains: 2 (maximum for Australia East)
- Update domains: 2
- Managed disks: Yes

### Step 3 — Deploy VM1
- Availability option: Availability Set → `OPS-CLOUD-007-Availability-Set`
- Image: Ubuntu 24.04 LTS | Size: Standard D2s v3 (Spot)
- Created new VNet `OPS-CLOUD-007-VNet` (10.0.0.0/16) during this step
- Inbound ports: HTTP(80) + SSH(22)

### Step 4 — Deploy VM2
- Same Availability Set as VM1 — critical
- Same VNet as VM1 — required for Load Balancer backend pool
- Size: Standard B1s (Spot quota exhausted after VM1)

### Step 5 — Install Nginx on Both VMs

```bash
sudo apt update && sudo apt install nginx -y

# VM1 — distinct page content for failover proof
echo "<h1>OPS-CLOUD-007 - VM1</h1>" | sudo tee /var/www/html/index.html

# VM2
echo "<h1>OPS-CLOUD-007 - VM2</h1>" | sudo tee /var/www/html/index.html
```

> 💡 `sudo tee` used instead of `>` redirect because `/var/www/html/` is root-owned. The `>` redirect runs as current user and is blocked by permissions. `sudo tee` writes as root.

### Step 6 — Create Standard Load Balancer
- SKU: Standard | Type: Public | Tier: Regional
- Frontend IP: Static Standard SKU public IP — `4.197.120.46`
- Availability zone: No Zone (VMs use Availability Set, not Availability Zones — must match)
- Backend Pool: VM1 + VM2 (both in same VNet)
- Health Probe: TCP port 80, 15 second interval
- LB Rule: Port 80 → Port 80, linked to health probe

---

## Testing & Proof of Failover

### NSG Verification
Confirmed NSG on VM1 had required inbound rules including `AllowAzureLoadBalancerInBound` — the health probe originates from Azure's internal IP `168.63.129.16` and must not be blocked.

### Test 1 — Load Balancer Serving Traffic ✅
Accessed `4.197.120.46` in browser → Page displayed: **OPS-CLOUD-007 - VM2**. LB routing traffic to healthy backend.

### Test 2 — Failover Proof ✅

| Event | Time | What Happened |
|-------|------|--------------|
| VM2 deallocated from portal | T+0s | VM2 status: Stopped (deallocated) |
| Health probe fails twice | T+15s | VM2 marked unhealthy |
| LB reroutes all traffic | T+15s | 100% traffic now going to VM1 |
| Browser refresh | T+15s | Page now shows: **OPS-CLOUD-007 - VM1** |
| VM2 restarted | Recovery | Probe passes → VM2 added back → 50/50 traffic |

**Zero manual intervention. Zero user impact. This is what high availability means in practice.**

---

## Key Decisions & Reasoning

**Why Availability Set over Availability Zones?**  
Availability Zones place VMs in separate physical buildings within the same region — stronger protection. Availability Sets place VMs on separate racks within the same building — sufficient for this lab. Availability Zones require Zone-redundant Load Balancer SKU. Availability Sets work with No Zone frontend IP. Matched the simpler option to the lab scope.

**Why Public LB not Internal?**  
Public LB gets a public IP — internet users reach it directly. Internal LB gets a private IP from the VNet — only internal resources can reach it. This web tier serves public internet users — Public is correct. Internal LB is for database tiers and internal APIs.

**Why Regional tier not Global?**  
Both VMs are in Australia East — no cross-region routing needed. Global tier is for multi-region architectures using Traffic Manager or cross-region Load Balancer.

**Why No Zone on frontend IP?**  
VMs use Availability Set (not Availability Zones). Selecting a specific zone on the frontend IP would create a zone mismatch. No Zone is the correct choice when VMs are in an Availability Set.

**Why port 80 not 443?**  
Standard LB is Layer 4 — cannot terminate SSL. HTTPS requires Application Gateway (Layer 7). Port 80 used to focus on HA concepts without certificate complexity.

---

## Problems Encountered & How I Resolved Them

**SSH key download failed for VM2**  
Browser failed to download VM2 private key during creation. Fix: App Service → Reset Password → set username and password → SSH using password auth for lab duration. Production fix: pre-create SSH key pairs and store in Key Vault — never rely on browser download.

**Spot vCPU quota exhausted for VM2**  
VM1 used Standard D2s v3 (2 vCPUs) on Spot. Only 1 Spot vCPU remained in subscription. Fix: changed VM2 to Standard B1s (1 vCPU). Production note: always use identical VM sizes behind a Load Balancer — mixed sizes create uneven capacity during failover.

**Nginx directory not found on VM1**  
`sudo tee /var/www/html/index.html` returned "No such file or directory". Root cause: Nginx not yet installed — the `/var/www/html/` directory is created by the Nginx installation, not by Ubuntu itself. Fix: install Nginx first, then run the tee command.

---

## Production Thinking — What Could Go Wrong

**LB frontend returns nothing — both VMs running**  
Three most likely causes:
1. **NSG blocking port 80** — health probe from `168.63.129.16` silently dropped. Both VMs marked unhealthy. No traffic forwarded. Fix: add inbound NSG rule for TCP port 80.
2. **LB misconfiguration** — break in the four-component chain (frontend → backend pool → health probe → LB rule). Fix: verify all four components exist and are linked.
3. **Nginx not running** — probe hits port 80, nothing listening, VM marked unhealthy. Fix: `sudo systemctl status nginx` → `sudo systemctl start nginx`.

**Mixed VM sizes in production**  
VM1 (D2s v3: 2 vCPU, 8 GiB) and VM2 (B1s: 1 vCPU, 1 GiB). If VM1 fails, VM2 receives 100% of traffic but has 12.5% of VM1's memory — likely OOM errors and eventual crash. Result: full outage instead of degraded service. Always use identical VM sizes in production.

**Session persistence confusion**  
LB uses 5-tuple hash (source IP, source port, destination IP, destination port, protocol) for session persistence. Same browser always hits same VM. To see both VMs serving — use different browser or incognito window which generates different source port and therefore different hash.

**Spot VM eviction**  
Azure can reclaim Spot capacity at any time. VM disappearing mid-test is not a networking failure — it is eviction. Eviction policy set to Stop/Deallocate to preserve VM config. Never use Spot VMs for production workloads requiring guaranteed availability.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| Fault domains = separate physical racks | VM1 on FD0, VM2 on FD1 — rack failure only takes one VM down |
| Update domains = staggered maintenance | Azure never reboots both VMs in same maintenance window |
| Cannot add VM to AS after creation | Availability Set created before any VM — mandatory build order |
| Standard LB secure by default | NSG port 80 rule required — without it health probe fails silently |
| Health probe = LB's only awareness | Nginx must be running before LB forwards any traffic |
| Layer 4 LB = TCP/IP only | Cannot see HTTP content, cannot terminate SSL |
| Same VNet required for backend pool | VM1 and VM2 both in OPS-CLOUD-007-VNet |
| Deallocate not Stop from inside OS | VMs stopped from Azure Portal — OS shutdown still incurs compute charges |

---

## Resource Cleanup

Delete `RG-OPS-CLOUD-007-Load-Balanced-Fleet` — cascades to remove Load Balancer, VMs, disks, NICs, public IPs, VNet, NSGs, and Availability Set.

> ⚠️ Always delete the entire Resource Group. Deleting only the VMs leaves the Load Balancer, disks, NICs, and public IPs still billing.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-007 | Phase 1 Console*  
*Next: [OPS-CLOUD-008 — Azure Functions + Storage Queue](../OPS-CLOUD-008-Azure-Functions-Storage-Queue/README.md)*
