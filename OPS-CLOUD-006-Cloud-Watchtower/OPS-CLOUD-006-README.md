# OPS-CLOUD-006 — Cloud Watchtower

> **Phase 1 — Azure Console (GUI)**  
> **Week 3 — Monitoring**  
> **Status:** ✅ Completed | **Date:** 17 May 2026

---

## Jira Ticket

| Field | Detail |
|-------|--------|
| **Ticket ID** | OPS-CLOUD-006 |
| **Priority** | High |
| **Epic** | Azure GUI Mastery — Week 3 Monitoring |
| **Assigned To** | Koteswar (Cloud Engineer) |

### Scenario

You have just joined a DevOps team at a fintech company. The infrastructure team has been flying blind — VMs spike to 100% CPU during batch jobs and nobody finds out until users complain. The on-call engineer only hears about it after the damage is done.

Your job: build a monitoring system that detects CPU spikes and emails the on-call engineer **before** users notice. The alert must fire automatically, resolve automatically, and require zero manual intervention during normal operation.

### Acceptance Criteria

- Log Analytics Workspace connected to Ubuntu VM via Azure Monitor Agent
- KQL query returns CPU data from `InsightsMetrics` table
- Alert rule fires when average CPU exceeds **75%** for 5 minutes
- Action Group sends email notification on alert fire
- Stress test proves alert fires at correct threshold
- Alert auto-resolves when CPU drops — resolution email received
- All KQL queries documented and explained

---

## What I Built

An end-to-end cloud monitoring pipeline — from VM performance data collection through to automated email alerting. Custom KQL log alerts built on top of Azure Monitor Agent data, with a stress test proving the pipeline works under real load.

| Service | Name | Purpose |
|---------|------|---------|
| Ubuntu VM | OPS-CLOUD-006-VM | Target resource to monitor |
| Log Analytics Workspace | ops-cloud-006-log-space | Central store — all KQL queries run here |
| Azure Monitor Agent | Auto-installed | Ships CPU data from VM to workspace |
| Alert Rule | OPS-CLOUD-006-CPU-Alert | Evaluates KQL every 5 minutes |
| Action Group | ops-cloud-006-action-group | Sends email when alert fires |

---

## Why I Built It

Default Azure metric alerts cover basic infrastructure health. But the moment your application writes to custom log tables, uses newer agents, or needs logic beyond simple thresholds — metric alerts fall short.

This project answers: **how do you build alerting that catches problems your default monitors miss, and notifies the right person before users are impacted?**

---

## Architecture

```
OPS-CLOUD-006-VM (Ubuntu 24.04 LTS)
         │
         │ Azure Monitor Agent (AMA)
         │ Ships data every 60 seconds
         ▼
ops-cloud-006-log-space (Log Analytics Workspace)
         │
         │ InsightsMetrics table
         │ Namespace: Processor
         │ Name: UtilizationPercentage
         ▼
KQL Alert Rule — OPS-CLOUD-006-CPU-Alert
         │ Runs every 5 minutes
         │ Threshold: AvgCPU > 75%
         │
    ┌────┴────┐
    │         │
  FIRED    NOT FIRED
    │
    ▼
ops-cloud-006-action-group (Global)
    │
    ▼
Email → koteswardt@gmail.com
Subject: CPU-Alert
```

> 📐 Architecture diagram: `architecture.png` (draw.io export)

---

## Key Concepts

### Why Custom Log Alert Instead of Metric Alert?

| | Metric Alert | Custom Log Alert (KQL) |
|-|-------------|----------------------|
| Cost | ~$0.10/month | ~$1.50/month |
| Speed | Near real-time | Scheduled (every 5 min) |
| Flexibility | Pre-built signals only | Any KQL logic |
| Use when | Standard CPU/memory/disk | Custom logic, AMA agent tables |

The VM uses **Azure Monitor Agent (AMA)** which writes to `InsightsMetrics` — not the standard metric stream. A built-in metric alert would not detect spikes from this agent. Custom KQL was required.

### InsightsMetrics vs Perf Table

| Agent | Table | Counter Format |
|-------|-------|---------------|
| Azure Monitor Agent (newer) | `InsightsMetrics` | Namespace + Name columns |
| Legacy MMA Agent | `Perf` | CounterName column |

Most online documentation still references `Perf`. Always explore the workspace first to find which table exists — never assume.

### Alert Lifecycle

| State | Trigger | What Happens |
|-------|---------|-------------|
| Not Fired | CPU < 75% | Rule evaluates every 5 min — no action |
| Fired | CPU > 75% sustained | Action Group triggers — email sent |
| Acknowledged | Human clicks Acknowledge | Signals investigating — stops repeat notifications |
| Resolved | CPU drops below 75% | Azure auto-resolves — resolution email sent |

**Acknowledge vs Resolve — frequently confused in interviews:**
- **Resolve** = automatic. Azure detects condition no longer breached and closes the alert.
- **Acknowledge** = manual. Engineer signals they are investigating. Stops repeated team notifications while working the incident.

---

## KQL Queries

### Query 1 — Discover All Tables
Run this first on any new workspace. Never assume which tables exist.

```kql
union withsource=$table *
| summarize count() by $table
| order by count_ desc
```

**Result:** `InsightsMetrics` (794 rows), `Heartbeat` (19 rows)

> ⚠️ Common mistake: `search *` conflicts with `summarize` — use `union withsource=$table *` instead. Always works.

### Query 2 — Explore Table Structure
See raw columns before writing queries. Never assume column names.

```kql
InsightsMetrics
| take 10
```

**Key columns discovered:** TimeGenerated, Computer, Namespace, Name, Val

### Query 3 — Find the CPU Counter

```kql
InsightsMetrics
| where Namespace == "Processor"
| summarize count() by Name
```

**Result:** `Name = UtilizationPercentage` (27 data points)

### Query 4 — Final CPU Alert Query (Production)
Calculates average CPU in 5-minute buckets. This is the exact query used in the alert rule.

```kql
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "Processor"
| where Name == "UtilizationPercentage"
| summarize AvgCPU = avg(Val) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated desc
```

| Line | What It Does |
|------|-------------|
| `where TimeGenerated > ago(30m)` | Only last 30 minutes of data |
| `where Namespace == "Processor"` | Filter to CPU metrics only |
| `where Name == "UtilizationPercentage"` | Specific CPU counter written by AMA agent |
| `summarize avg(Val) by bin(..., 5m)` | Average CPU grouped into 5-minute buckets |
| `order by TimeGenerated desc` | Newest results first |

---

## Alert Configuration

### Alert Rule Settings

| Setting | Value & Reasoning |
|---------|------------------|
| Scope | `ops-cloud-006-log-space` — data lives in workspace, not VM |
| Signal Type | Custom Log Search — InsightsMetrics requires KQL |
| Measure | AvgCPU — the calculated column from the KQL summarize line |
| Aggregation Type | Average — prevents false positives from momentary 1-second spikes |
| Aggregation Granularity | 5 minutes — matches `bin()` size in KQL query |
| Operator | Greater than |
| Threshold | 75% — warns before 100%, gives response time |
| Frequency | Every 5 minutes — Azure runs KQL on this schedule |
| Severity | 2 — Warning (VM still running, not a full outage) |
| Monthly Cost | ~$1.50 USD |

### Action Group Settings

| Setting | Value |
|---------|-------|
| Name | ops-cloud-006-action-group |
| Region | **Global** — Australia East not available for Action Groups |
| Notification | Email/SMS/Push/Voice |
| Email | koteswardt@gmail.com |

> 💡 Action Groups are a global notification infrastructure service — not region-specific. This surprises most people the first time. Always set to Global.

---

## Stress Test Results

```bash
# Install stress tool (stress package deprecated on Ubuntu 24.04)
sudo apt update && sudo apt install stress-ng -y

# Run stress test — 4 CPU workers for 300 seconds
stress-ng --cpu 4 --timeout 300 --metrics-brief
```

| Item | Result |
|------|--------|
| CPU Reached | 84.4% average (threshold: 75%) |
| Alert Fired At | 5/17/2026 9:19:20 AM UTC |
| Email Received | ✅ Subject: Fired: Sev3 Azure Monitor Alert |
| Auto-Resolved | ✅ Resolution email received after CPU dropped to 0.6% |

---

## Key Decisions & Reasoning

**Why scope alert to Log Analytics Workspace, not the VM?**  
The alert signal is a log query — data lives in the workspace. Scoping to the VM only allows Metric signals, not custom KQL log queries.

**Why Average aggregation over 5 minutes?**  
Prevents false positives from momentary CPU spikes that last 1–2 seconds. A 5-minute average represents a sustained problem worth waking someone up for.

**Why threshold at 75% not 90%?**  
Warns before hitting 100% — gives the on-call engineer response time to investigate before users are impacted. At 90%, by the time the alert fires and the engineer responds, the system may already be at 100%.

**Why Action Group region is Global?**  
Australia East is not available for Action Groups. They are a global notification infrastructure service hosted in specific regions only. Always set to Global.

---

## Problems Encountered & How I Resolved Them

**`stress` package not available on Ubuntu 24.04**  
`sudo apt install stress -y` returned "Unable to locate package stress". Fix: use `stress-ng` — the actively maintained modern replacement. Same functionality, different package name.

**Portal navigation — Insights renamed to Monitor**  
Azure renames blades frequently. The correct path to connect VM to workspace: VM → Monitor blade → Configure button in the "Unlock enhanced monitoring" banner. Navigate by purpose, not label.

**Default Measure was "Table rows" not "AvgCPU"**  
Alert rule defaulted to counting table rows instead of evaluating the actual CPU value. Fixed by changing Measure from "Table rows" to "AvgCPU" — the column produced by the `summarize` line in the KQL query.

**`search *` syntax error**  
KQL error on `order by desc` line when using `search *`. Root cause: `search *` conflicts with `summarize`. Fix: use `union withsource=$table *` — always explicit and always works.

---

## Production Thinking — What Could Go Wrong

**Alert fires but no email received**  
Action Group misconfigured or email address typo. Verify: Action Group → Notifications tab → correct email. Test using the "Test action group" button — sends a test notification without waiting for a real alert.

**Alert never fires despite CPU spiking**  
Three possible causes: (1) Measure still set to "Table rows" not "AvgCPU" — evaluating row count not CPU percentage. (2) AMA agent not connected — no data flowing to workspace. (3) Wrong table — query targeting `Perf` but data is in `InsightsMetrics`. Fix: run KQL query manually in workspace and verify it returns data before creating the alert rule.

**Monitoring 10 VMs — do you create 10 alert rules?**  
No. Scope the alert rule to the Resource Group or entire Log Analytics Workspace. The KQL query groups by `Computer` column — all VMs in the workspace are covered by one rule. The alert fires per computer so you can see which VM triggered it.

---

## Concepts Applied from Coursework

| Concept | Where It Appeared |
|---------|------------------|
| Log Analytics Workspace as monitoring brain | All KQL queries run against ops-cloud-006-log-space |
| KQL for querying log data | 4 progressively refined queries built from scratch |
| InsightsMetrics table (AMA agent) | Discovered via union query — not assumed |
| Alert lifecycle (Fired → Acknowledged → Resolved) | Observed end-to-end during stress test |
| Action Groups for notification | Email triggered on alert fire, resolution email on auto-resolve |
| Metric alerts vs Log alerts | Conscious decision — AMA agent data requires KQL |

---

## Resource Cleanup

Delete `RG-OPS-CLOUD-006-Cloud-Watchtower` — cascades to remove VM, Log Analytics Workspace, Alert Rule, and Action Group.

> ⚠️ Alert rules have a per-rule monthly charge (~$1.50) regardless of how many times they fire. Always clean up after lab work.

---

*Koteswar Rao — Azure Cloud Journey | OPS-CLOUD-006 | Phase 1 Console*  
*Next: [OPS-CLOUD-007 — Load-Balanced Fleet](../OPS-CLOUD-007-Load-Balanced-Fleet/README.md)*
