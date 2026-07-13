# OPS-CLOUD-P2-003 — Automate Cross-Region VNet Peering

**Phase:** 2 — Azure CLI + Bash Automation
**Status:** ✅ Complete
**Date:** 12–14 July 2026

---

## Jira Ticket

**OPS-CLOUD-P2-003 : Automate Cross-Region VNet Peering**
**Sprint:** Week 2 — Networking Automation
**Type:** Infrastructure Automation

### Problem Statement / Scenario

A company needs two regions to talk to each other privately — think a
database replica for disaster recovery, or an app split across regions
for latency. The traffic between those two regions needs to stay off
the public internet, especially if it's database traffic. I already
built this once by hand in the Portal in OPS-CLOUD-002 (Australia East
↔ Central India). This time the goal was to reproduce it entirely
through the CLI, so it's repeatable instead of 20-30 minutes of manual
clicking that's easy to get wrong.

### What I'm Solving For

- Two VNets in two different regions that can reach each other over
  **private IP addresses**, routed across Azure's private backbone
  instead of the public internet
- Prove it with a real before/after connectivity test, not just a
  "Connected" status in the Portal
- Build it entirely via CLI — no Portal clicks for resource creation
- Keep the whole thing simple enough for a lab, while still
  understanding what changes in a real production setup

---

## What I Built

One Resource Group, two VNets in two regions with non-overlapping
address spaces, one VM per VNet, and a bidirectional peering link
between them.

| Component | Region 1 (Australia East) | Region 2 (Central India) |
|---|---|---|
| VNet | OPS-CLOUD-P2-003-Vnet1 — `10.0.0.0/16` | OPS-CLOUD-P2-003-Vnet2 — `10.1.0.0/16` |
| Subnet | OPS-CLOUD-P2-003-subnet1 — `10.0.0.0/24` | OPS-CLOUD-P2-003-subnet2 — `10.1.0.0/24` |
| VM | OPS-CLOUD-P2-003-VM1 | OPS-CLOUD-P2-003-VM2 |
| Private IP | `10.0.0.4` | `10.1.0.4` |
| Public IP | `20.211.5.58` | `4.224.120.126` |

Peering links: `Vnet1-to-Vnet2` and `Vnet2-to-Vnet1` — both created via
separate `az network vnet peering create` calls, both confirmed
**Connected** and **Fully Synchronized** in the Portal.

I ran the same ping test twice — once **before** peering (both
directions failed, 100% packet loss) and once **after** peering (both
directions succeeded, 0% packet loss, ~147ms RTT). That RTT lines up
with what OPS-CLOUD-002 measured for the same two regions in the
Portal, which was a nice sanity check that the CLI build is behaving
the same way the manual build did.

---

## Why I Built It This Way

**One Resource Group, not two.**
I went back and forth on this. Technically an RG is just a management
boundary — it doesn't restrict what regions the resources inside it
live in, so one RG works fine here. In production I'd lean toward
separate RGs per region (like I did in OPS-CLOUD-002), because it
mirrors how larger orgs actually split ownership by region and means
deleting one region's resources doesn't touch the other's lifecycle.
For a short-lived lab with a fixed teardown date, that benefit barely
matters, so I kept it simple with one RG.

**`/16` for the VNet, `/24` for the subnet.**
`/16` gives the company room to grow — 65,536 addresses is far more
than this lab needs, but it means if they add more subnets or
projects into this VNet later, they're not boxed in. `/24` per subnet
is a sensible chunk (256 addresses) without over-allocating.

**Non-overlapping address spaces (`10.0.x.x` vs `10.1.x.x`).**
This is the one rule that will break peering outright if you get it
wrong. I actually made this mistake myself while drafting the
variables — more on that below.

**CLI over Portal.**
Same reasoning as every Phase 2 ticket: the Portal version of this
(OPS-CLOUD-002) took roughly 20-30 minutes of clicking. The script
does the same work in a fraction of that, and it's rerunnable — if I
need this exact setup again for a new project or a different region
pair, I'm editing variables, not re-doing the whole manual flow.

**Where this actually gets used in production.**
VNet peering like this is the backbone of things like multi-region
database replication / disaster recovery (a standby replica synced
privately in a second region), global applications with regional
compute (app servers close to users in each region, sharing one
private backend), and — at bigger scale — hub-and-spoke architectures,
where instead of every VNet peering directly with every other VNet
(which doesn't scale, since peering isn't transitive), everything
peers into one central hub. That's actually the next thing on my
Intermediate track.

---

## Mistakes I Made and What I Learned

**1. Almost broke the non-overlap rule without noticing.**
Early on I typed `10.0.0.1/16` for Vnet1 and `10.0.0.2/16` for Vnet2.
At a glance that looks like two different addresses, but a `/16`
prefix only cares about the first two octets — both of these are
`10.0.x.x`, so they weren't different address spaces at all, and the
`.1`/`.2` I'd put in the third octet were invalid host bits for a
`/16` network address anyway. Claude caught it before I ran it, but
it drove home that CIDR math isn't just "make the numbers look
different" — you have to know which octets the prefix length actually
protects.

**2. Confused a VNet's location with a restriction on its resources.**
I assumed a Resource Group's location meant everything inside it had
to live in that same region. It doesn't — an RG's location is just
where its own metadata sits. You can create a VNet in Australia East
and another in Central India inside the exact same RG, which is
exactly what let me use one RG for this whole project.

**3. Tried to ping a private IP from my own laptop.**
Before I understood the private/public IP distinction properly, I ran
`ssh azureuser@10.0.0.4` straight from my MacBook and got "Network is
unreachable" immediately. That's because `10.0.0.4` is a private IP —
it only exists inside that VNet. My laptop, sitting on my home
network, has no route to it at all, peered or not. The actual test
has to run **from inside** one VM, targeting the other VM's private IP
— not from my own machine.

**4. CLI rejected an API version that the Portal was using fine.**
When I tried `az network vnet show ... --query id` to grab a VNet's
resource ID, the CLI threw `InvalidApiVersionParameter` for
`2025-07-01` — even right after running `az upgrade` and confirming I
was on the latest CLI version. But when I opened the same VNet's
**Resource JSON** in the Portal, it was using `apiVersion: 2025-07-01`
without any issue. So the Portal and my local CLI were working against
different API version sets at the same moment — I worked around it by
grabbing the VNet's Resource ID straight from the Portal's JSON view
instead of the CLI command. Good reminder that "my CLI is up to date"
doesn't guarantee it's in sync with everything the Portal can do.

**5. Peering is genuinely two separate operations, not one.**
I already knew from OPS-CLOUD-002 that peering isn't automatically
bidirectional, but doing it via CLI made it a lot more concrete — the
Portal's single "Add peering" form quietly fires two API calls behind
the scenes. Writing this by hand meant I had to explicitly create
`Vnet1-to-Vnet2` and then, separately, `Vnet2-to-Vnet1` — with the
`--vnet-name` (local) and `--remote-vnet` (the other side) flipped
between the two calls. Much harder to gloss over when you're the one
typing both commands.

---

## What Could Go Wrong (Production Thinking)

**Q: If I ran this whole script a second time without deleting the RG
first, what happens?**

Some of it would fail loudly and safely — `az group create` and
`az network vnet create` are idempotent-ish, they'd either succeed
again cleanly or just confirm the existing state matches. But
`az vm create` and `az network vnet peering create` would likely
throw "already exists" errors partway through, leaving me with a
script that dies in the middle rather than cleanly reporting "nothing
to do here." For a real production script I'd want existence checks
(`az group exists`, `az network vnet show` wrapped in an `if`) before
each block, so the script can be safely re-run without babysitting it
through failures.

---

## Requirements (from the ticket)

1. Resource Group created via CLI
2. Two VNets in two regions, non-overlapping CIDRs
3. Two subnets, one per VNet
4. Two VMs, one per VNet, for connectivity testing
5. Bidirectional peering (both `az network vnet peering create` calls)
6. Peering status verified as Connected + Fully Synchronized, both sides
7. Private connectivity proven with a before/after ping test

All requirements met — see screenshots below.

---

## Deployment Script

`deploy-vnet-peering.sh`

```bash
#!/bin/bash

# ── Variables ──
RG="OPS-CLOUD-P2-003-RG"
Location1="australiaeast"
Location2="centralindia"
MYVNET1="OPS-CLOUD-P2-003-Vnet1"
MYVNET2="OPS-CLOUD-P2-003-Vnet2"
MYSUBNET1="OPS-CLOUD-P2-003-subnet1"
MYSUBNET2="OPS-CLOUD-P2-003-subnet2"
VMNAME1="OPS-CLOUD-P2-003-VM1"
VMNAME2="OPS-CLOUD-P2-003-VM2"
VMImage="Ubuntu2204"
VMsize="Standard_B1s"
VNET1_PREFIX="10.0.0.0/16"
SUBNET1_PREFIX="10.0.0.0/24"
VNET2_PREFIX="10.1.0.0/16"
SUBNET2_PREFIX="10.1.0.0/24"
ADMIN_USER="azureuser"

# ── Resource Group ──
az group create \
  --name "$RG" \
  --location "$Location1"

# ── VNet + Subnet (Region 1) ──
az network vnet create \
  --resource-group "$RG" \
  --name "$MYVNET1" \
  --address-prefix "$VNET1_PREFIX" \
  --subnet-name "$MYSUBNET1" \
  --subnet-prefix "$SUBNET1_PREFIX" \
  --location "$Location1"

# ── VNet + Subnet (Region 2) ──
az network vnet create \
  --resource-group "$RG" \
  --name "$MYVNET2" \
  --address-prefix "$VNET2_PREFIX" \
  --subnet-name "$MYSUBNET2" \
  --subnet-prefix "$SUBNET2_PREFIX" \
  --location "$Location2"

# ── VM (Region 1) ──
az vm create \
  --resource-group "$RG" \
  --name "$VMNAME1" \
  --image "$VMImage" \
  --size "$VMsize" \
  --vnet-name "$MYVNET1" \
  --subnet "$MYSUBNET1" \
  --admin-username "$ADMIN_USER" \
  --authentication-type ssh \
  --generate-ssh-keys \
  --location "$Location1"

# ── VM (Region 2) ──
az vm create \
  --resource-group "$RG" \
  --name "$VMNAME2" \
  --image "$VMImage" \
  --size "$VMsize" \
  --vnet-name "$MYVNET2" \
  --subnet "$MYSUBNET2" \
  --admin-username "$ADMIN_USER" \
  --authentication-type ssh \
  --generate-ssh-keys \
  --location "$Location2"

# ── Resource IDs for peering (pulled from Portal JSON due to a local
#    CLI / API-version mismatch — see README "Mistakes" section) ──
VNET1_ID="/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/$MYVNET1"
VNET2_ID="/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/$MYVNET2"

# ── Peering: Vnet1 → Vnet2 ──
az network vnet peering create \
  --resource-group "$RG" \
  --name "Vnet1-to-Vnet2" \
  --vnet-name "$MYVNET1" \
  --remote-vnet "$VNET2_ID" \
  --allow-vnet-access

# ── Peering: Vnet2 → Vnet1 ──
az network vnet peering create \
  --resource-group "$RG" \
  --name "Vnet2-to-Vnet1" \
  --vnet-name "$MYVNET2" \
  --remote-vnet "$VNET1_ID" \
  --allow-vnet-access
```

*(Subscription ID redacted in this README copy — the real script has
the literal value.)*

---

## Portal Verification Screenshots

1. **Resource Group before anything exists** — confirms a clean slate.
2. **RG + Vnet1 created** — CLI output showing `provisioningState:
   Succeeded` for both.
3. **Vnet2 + both VMs created** — Portal view confirming VM1
   (Australia East) and VM2 (Central India), both `Running`, public
   IPs assigned.
4. **Pre-peering ping test, VM1 → VM2** — 100% packet loss.
5. **Pre-peering ping test, VM2 → VM1** — 100% packet loss.
6. **Peering status — Vnet1's Peerings blade** — `Vnet1-to-Vnet2`,
   Connected, Fully Synchronized.
7. **Peering status — Vnet2's Peerings blade** — `Vnet2-to-Vnet1`,
   Connected, Fully Synchronized.
8. **Post-peering ping test, both directions** — 0% packet loss,
   ~147-150ms RTT.

---

## Cleanup

Deleted the entire Resource Group (`OPS-CLOUD-P2-003-RG`) after
capturing all verification screenshots — same lesson as always: delete
the whole RG, not individual resources, so nothing (disks, NICs,
public IPs) gets left behind still billing.

*End of Document — OPS-CLOUD-P2-003*
