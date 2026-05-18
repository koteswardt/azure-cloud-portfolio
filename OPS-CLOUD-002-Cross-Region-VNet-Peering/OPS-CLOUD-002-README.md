# OPS-CLOUD-002 — Cross-Region VNet Peering

> **Phase 1 — Azure Console (GUI)**  
> **Week 1 — Networking Foundation**  
> **Status:** ✅ Completed | **Date:** 14 April 2026

---

## What I Built

Two Azure Virtual Networks in geographically separate regions — Australia East and Central India — connected via VNet Peering. Two Linux VMs, one in each VNet, communicating exclusively over private IP addresses with zero traffic touching the public internet.

| Component | Australia East | Central India |
|-----------|---------------|---------------|
| Resource Group | VnetAus | RG-OPS-CLOUD-002-Vnet-Ind |
| VNet Name | ausnetcent | Vnetind |
| Address Space | 10.0.0.0/16 | 10.1.0.0/16 |
| Subnet | ausnet (10.0.0.0/24) | indnet (10.1.0.0/24) |
| VM Name | Vmtest1 | Vmtest2 |
| VM Private IP | 10.0.0.4 | 10.1.0.4 |
| VM Size | Standard D2s v3 (Spot) | Standard D2s v3 (Spot) |

---

## Why I Built It

VNet Peering is one of the most fundamental networking skills in Azure. Any real-world architecture that spans multiple regions — disaster recovery, global applications, hub-and-spoke networks — requires understanding how to connect isolated network spaces privately.

The core question this project answers: **how do two VMs in completely different countries talk to each other without going through the public internet?**

---

## Architecture

```
Australia East                          Central India
──────────────────────                  ──────────────────────
VNet: ausnetcent                        VNet: Vnetind
      10.0.0.0/16                             10.1.0.0/16
│                                       │
└── Subnet: ausnet                      └── Subnet: indnet
    10.0.0.0/24                             10.1.0.0/24
    │                                       │
    └── Vmtest1                             └── Vmtest2
        Private IP: 10.0.0.4                    Private IP: 10.1.0.4
        Public IP:  20.211.152.130              Public IP:  4.188.83.81

        │◄──────── VNet Peering ────────►│
              ausnetcent-to-vnetind
              vnetind-to-ausnetcent
              (Azure global backbone — NOT public internet)
              Real-world RTT: ~141ms
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Key Concept: The Non-Overlap Rule

A VNet is the entire private network space for your Azure resources. When peering two VNets, their address spaces **must not overlap**.

If both VNets used `10.0.0.0/16`, Azure cannot build unambiguous routing tables — a packet destined for `10.0.0.5` would have two possible destinations and peering fails at configuration time.

| VNet | Address Space | Why |
|------|--------------|-----|
| ausnetcent | 10.0.0.0/16 | First VNet — baseline |
| Vnetind | 10.1.0.0/16 | Deliberately different — satisfies non-overlap rule |

---

## Key Concept: Bidirectional Peering

VNet Peering is not automatically symmetric. Azure requires a peering link configured from **both sides**. When you fill in the peering form inside `ausnetcent`, Azure creates both links simultaneously:

| Peering Link Name | Visible In |
|------------------|-----------|
| ausnetcent-to-vnetind | ausnetcent's Peerings blade |
| vnetind-to-ausnetcent | Vnetind's Peerings blade |

Both sides must show **Connected + Fully Synchronized** before traffic can flow.

---

## Build Steps

### Step 1 — Create VNet in Australia East
- VNet: `ausnetcent` | Address Space: `10.0.0.0/16`
- Subnet: `ausnet` | Range: `10.0.0.0/24`

### Step 2 — Create VNet in Central India
- VNet: `Vnetind` | Address Space: `10.1.0.0/16`
- Subnet: `indnet` | Range: `10.1.0.0/24`

### Step 3 — Apply Tags to All Resources

| Tag | Value |
|-----|-------|
| Project | OPS-CLOUD-002 |
| Environment | Lab |
| Owner | Kotesh |

### Step 4 — Deploy a VM in Each VNet
- Both VMs: Ubuntu 24.04 LTS, Standard D2s v3, Azure Spot pricing
- NSG inbound rules: SSH (22), HTTP (80), ICMP (for ping test)

### Step 5 — Configure VNet Peering
- Initiated from `ausnetcent` → Peerings blade → Add
- Azure created both links in one action

### Step 6 — Verify Connected Status
- Both sides confirmed: **Connected + Fully Synchronized**

### Step 7 — Ping Test (Proof of Private Routing)
- SSH into Vmtest1 → `ping 10.1.0.4` → 5/5 packets, ~142ms RTT
- SSH into Vmtest2 → `ping 10.0.0.4` → 10/10 packets, ~141ms RTT
- 0% packet loss. Traffic routed over Azure's private backbone.

---

## Key Decisions & Reasoning

**Why D2s v3 over B-series?**  
B-series VMs are burstable — they share CPU with other tenants and are designed for low-traffic workloads. For a networking test where consistent ping results matter, D2s v3 (general purpose, dedicated compute) gives reliable baseline performance.

**Why Azure Spot pricing?**  
Spot VMs use spare Azure capacity at up to 90% discount. For a lab that runs for less than an hour, Spot is the correct cost decision. The eviction risk is acceptable — eviction policy was set to Stop/Deallocate to preserve VM configuration if eviction occurred.

**Why separate Resource Groups per region?**  
Mirrors real-world practice where network resources in different regions are managed independently. Enables separate lifecycle management — you can delete the India resources without touching the Australia resources.

**Why ICMP allowed in NSG?**  
VNet Peering showing "Connected" does not guarantee ping works. NSGs can silently drop ICMP traffic even when the peering link is healthy. Explicitly allowing ICMP was required to prove private routing worked — not just that the peering link existed.

---

## Problems Encountered & How I Resolved Them

**Understanding Local vs Remote in the peering form**  
The peering form inside `ausnetcent` has two sections — Local (ausnetcent) and Remote (Vnetind). It's easy to confuse which side you're naming. The key insight: Azure creates both links from this single form. You only need to initiate from one side.

**Peering is not transitive**  
If ausnetcent peers with Vnetind, and Vnetind peers with a third VNet, ausnetcent cannot automatically reach the third VNet through Vnetind. Each pair that needs to communicate requires its own direct peering link. Critical for hub-and-spoke architectures.

---

## Production Thinking — What Could Go Wrong

**Overlapping address spaces**  
Adding a third VNet with `10.0.0.0/16` (same as ausnetcent) — peering fails immediately. Azure rejects the configuration because routing becomes ambiguous. Fix: always plan your IP address scheme upfront using non-overlapping ranges.

**Cross-region peering data transfer costs**  
Peering across regions incurs charges on both ingress and egress. For this lab, ping traffic was negligible. In production with high-throughput workloads, cross-region peering costs accumulate significantly — sometimes a VPN Gateway or ExpressRoute is more cost-effective at scale.

**Spot VM eviction mid-test**  
Azure can reclaim Spot capacity at any time. If a VM disappears during testing it is not a networking failure — it is eviction. Eviction policy set to Stop/Deallocate preserved VM configuration. Never use Spot VMs for production workloads that require guaranteed availability.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| VNet address spaces must not overlap | ausnetcent = 10.0.0.0/16, Vnetind = 10.1.0.0/16 — deliberately different |
| Subnets divide VNets | ausnet inside ausnetcent, indnet inside Vnetind |
| NSG controls traffic at subnet level | ICMP explicitly allowed to permit ping across peering |
| Region = geographic placement | Australia East + Central India — ~141ms RTT reflects real distance |
| Stop vs Deallocate billing trap | Both VMs deallocated from portal after testing |
| Peering is bidirectional and explicit | Both links created and verified Connected |
| Tags for cost management | Project, Environment, Owner, Region tags on all resources |

---

## Resource Cleanup

Both Resource Groups deleted after documentation captured. Deleting the Resource Group cascades — removes VMs, NICs, disks, public IPs, VNets, NSGs in one action.

> ⚠️ Always delete the entire Resource Group. Deleting only the VM leaves disks and public IPs still billing.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-002 | Phase 1 Console*  
*Next: [OPS-CLOUD-003 — Global CDN Static Host](../OPS-CLOUD-003-Global-CDN-Static-Host/README.md)*
