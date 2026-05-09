# OPS-CLOUD-001 — IaaS vs PaaS: Azure Web Hosting Dual-Challenge

> **Phase 1 — Azure Console (GUI)**  
> **Week 1 — Compute & Networking Foundation**  
> **Status:** ✅ Completed

---

## What I Built

Two separate web hosting deployments using fundamentally different Azure service models — side by side — to understand the real trade-offs between IaaS and PaaS in a hands-on environment.

| Part | Service Model | Azure Service | Outcome |
|------|--------------|---------------|---------|
| Part 1 | IaaS | Linux Virtual Machine + Apache | Custom web server with full OS control |
| Part 2 | PaaS | Azure Blob Storage (Static Website) | Managed hosting with zero OS management |

---

## Why I Built It

Before moving into advanced Azure architectures, I needed a concrete answer to a foundational question: **when do you choose a VM over a managed service?**

Reading about IaaS vs PaaS in theory doesn't answer that. Building both — for the same goal (serve a webpage) — makes the trade-offs undeniable. Every decision in this project forced a choice: do I want control, or do I want simplicity?

---

## Architecture

```
Part 1 — IaaS
─────────────────────────────────────────
Internet → Public IP (Static) → NSG → Linux VM (Ubuntu 24.04) → Apache → index.html
           20.11.32.181         Port 80 (HTTP)
                                Port 22 (SSH)

Part 2 — PaaS
─────────────────────────────────────────
Internet → Azure Blob Storage → $web container → index.html
           Primary Endpoint URL (auto-generated)
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Part 1: IaaS — Linux VM + Apache

### Network & Security Configuration

- **Virtual Network:** `Linux-Web-Srv-vnet` — isolates the server in a private address space
- **Network Security Group (NSG):** Inbound rules allowing Port 22 (SSH) and Port 80 (HTTP) only
- **Public IP:** Static Standard SKU — `20.11.32.181`

**Why Static IP?**  
A Dynamic IP changes every time the VM is stopped and restarted. For a web server, that means your endpoint changes every time you save costs by deallocating overnight. Static IP costs a small amount but guarantees the address never changes — essential for DNS and consistent access.

### Server Provisioning

- **OS:** Ubuntu 24.04 LTS
- **Authentication:** SSH key pair (.pem file)
- **Permission fix on macOS:** `chmod 700 [keyname].pem` — SSH refuses to connect if the key file is group- or world-readable. This is a security requirement enforced by the SSH client, not Azure.

### Web Server Installation

Connected via SSH and ran the following sequence:

```bash
sudo apt update
sudo apt install apache2 -y
sudo nano /var/www/html/index.html
```

Apache serves from `/var/www/html/` by default. Editing `index.html` directly replaced the default Apache page with a custom landing page.

---

## Part 2: PaaS — Blob Storage Static Website

### Storage Account Setup

- **Service:** Azure Blob Storage
- **Redundancy:** LRS (Locally-Redundant Storage) — 3 copies within one data centre, sufficient for a lab environment
- **Feature enabled:** Static website hosting

### The $web Container

When Static website hosting is enabled, Azure automatically creates two containers:

| Container | Purpose |
|-----------|---------|
| `$web` | Public-facing folder — upload HTML, CSS, JS here |
| `$logs` | Azure stores traffic and access logs here |

Uploaded `index.html` to `$web`. Accessed the site via the **Primary Endpoint URL** provided by Azure — no DNS configuration, no SSL setup, no server management required.

---

## IaaS vs PaaS — Comparison

| Aspect | IaaS (Linux VM) | PaaS (Blob Storage) |
|--------|----------------|---------------------|
| Control | Full OS and stack control | Managed entirely by Azure |
| Setup Effort | High — manual SSH, package install, config | Low — enable feature, upload file |
| OS Management | My responsibility (patching, updates) | No OS to manage |
| Scalability | Manual — resize VM, add load balancer | Automatic |
| Cost Model | Pay for VM uptime (even idle) | Pay per storage used and requests served |
| Best For | Custom server apps, legacy software | Static websites, SPAs, documentation |

---

## Key Decisions & Reasoning

**Why Static IP over Dynamic?**  
Static IPs guarantee a consistent public address. Dynamic IPs are free when the VM is stopped (deallocated), but the address changes on every restart. For any server others need to reach reliably, static is the correct choice — the small cost is worth the operational simplicity.

**Why LRS for the storage account?**  
This is a lab environment with no production traffic. LRS stores 3 copies within a single data centre — more than enough for a test site. In production with real traffic, ZRS (Zone-Redundant Storage) would protect against a single data centre failure, and GRS (Geo-Redundant Storage) would protect against a full regional outage.

**Why Apache over Nginx?**  
For a basic static page, either works. Apache is the standard choice on Ubuntu for introductory deployments — well-documented, default package repositories, widely supported. Nginx would be appropriate where performance under high concurrent connections matters.

---

## Problems Encountered & How I Resolved Them

**SSH permission error on macOS**  
`chmod 700 [keyname].pem` — SSH clients reject keys that are readable by other users on the system. The fix is to restrict the key file to owner-only access.

**Understanding the billing trap**  
Stopping a VM from inside the OS (`sudo shutdown`) does NOT stop Azure billing for compute — the hardware is still allocated to you. The correct action is to **Deallocate** from the Azure Portal. Disk charges always apply regardless of VM state.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| IaaS vs PaaS trade-offs | The core comparison — full control vs managed simplicity |
| Static vs Dynamic IP billing | Used Static IP; understand the cost reason behind the choice |
| NSG rules for network security | Port 80 and 22 opened; all other inbound traffic blocked |
| Stop vs Deallocate billing trap | Deallocated from portal after testing — not shut down from inside OS |
| Blob Storage Hot Tier | Static website files in $web default to Hot (Inferred) — correct for frequently accessed content |
| VNet + Subnet isolation | VM placed inside a dedicated VNet/Subnet, not exposed directly |

---

## Resource Cleanup

Deleted the Resource Group after documentation was captured. Deleting the Resource Group cascades and removes all child resources — VM, NIC, disk, public IP, VNet, NSG — in a single action.

> ⚠️ Always delete the entire Resource Group, not individual resources. Deleting the VM but leaving the disk and public IP still incurs storage and IP charges.

---

## Screenshots

| Screenshot | Description |
|-----------|-------------|
| `screenshots/01-vm-networking-nsg.png` | VM Networking tab showing Port 80 and Port 22 NSG rules |
| `screenshots/02-ssh-apache-status.png` | Terminal showing successful SSH connection and Apache running |
| `screenshots/03-blob-static-website.png` | Storage Account Static website hosting enabled |
| `screenshots/04-web-container-upload.png` | $web container with index.html uploaded |
| `screenshots/05-live-site-blob.png` | Live site via Blob Storage primary endpoint URL |
| `screenshots/06-live-site-vm.png` | Live site via VM public IP |

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-001 | Phase 1 Console*  
*Next: [OPS-CLOUD-002 — Cross-Region VNet Peering](../OPS-CLOUD-002-Cross-Region-VNet-Peering/README.md)*
