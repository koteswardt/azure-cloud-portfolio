# OPS-CLOUD-P2-001 — Automate Linux VM + Apache Deployment

**Phase:** 2 — Azure CLI + Bash Automation
**Sprint:** Week 1 — Compute & Storage Automation
**Status:** ✅ Complete

---

## Aim

Reduce the time and human error involved in manually spinning up a VM
through the Azure Portal — for example, forgetting to enable the right
NSG rule. To avoid that, I wrote a reusable Bash automation script.
To reuse it for a new environment, I only need to modify the variable
names (VM size, location, resource group name, etc.) based on the
requirement — the logic stays the same.

## What Gets Created, In Order

1. **Resource Group** — the container everything else lives inside.
2. **VNet + Subnet** — isolates this environment, similar to creating
   a private network segment inside a larger company network. Used
   `/16` for the VNet (65,536 addresses) and `/24` for the subnet
   (256 addresses) — a `/24` was enough for this small project's
   needs, but sizing the VNet at `/16` leaves room to add more
   subnets later without re-architecting, since a company-scale
   network needs more flexibility than a single project does.
3. **Virtual Machine** — Ubuntu 22.04, `Standard_B1s`, SSH key-based
   authentication only (no passwords) — more secure than
   password auth.
4. **NSG Rules** — port 22 (SSH) is open by default when the VM is
   created; port 80 (HTTP) was explicitly opened for public web
   traffic reaching Apache.
5. **Apache2** — installed remotely via `az vm run-command`, without
   ever SSHing into the VM manually.
6. **Public IP** — captured and printed by the script at the end of
   the run.

## Dependency Order — Portal vs CLI

Even though the Azure Portal's VM wizard feels like you configure the
VM first and the VNet "at the end," Azure always creates the VNet and
subnet **before** the VM, behind the scenes — the VM's network
interface (NIC) needs an existing subnet to attach to before it can
be given a private IP. The Portal just batches all of this into one
"Review + Create" click, hiding the real order. Scripting it with CLI
makes the dependency chain explicit:

```
Resource Group  →  VNet / Subnet  →  NIC (auto-created)  →  Virtual Machine
```

## Commands Used

**Resource Group**
```bash
az group create --name "$RG" --location "$Location"
```

**VNet + Subnet**
```bash
az network vnet create \
  --resource-group "$RG" \
  --name "$MYVNET" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "$MYSUBNET" \
  --subnet-prefix "10.0.1.0/24" \
  --location "$Location"
```

**Virtual Machine (SSH key auth)**
```bash
az vm create \
  --resource-group "$RG" \
  --name "$VMNAME" \
  --image "$VMImage" \
  --size "$VMsize" \
  --vnet-name "$MYVNET" \
  --subnet "$MYSUBNET" \
  --admin-username "azureuser" \
  --authentication-type ssh \
  --generate-ssh-keys \
  --location "$Location"
```

**Open Port 80**
```bash
az vm open-port --resource-group "$RG" --name "$VMNAME" --port 80
```

**Install Apache Remotely**
```bash
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VMNAME" \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y apache2"
```

**Print Public IP**
```bash
IP=$(az vm show -d --resource-group "$RG" --name "$VMNAME" --query publicIps -o tsv)
echo "Apache deployed. Visit: http://$IP"
```

## Production Considerations (Beyond This Ticket's Scope)

This ticket intentionally leaves port 22 open on the public IP for
simplicity in a dev/learning environment. In a real production
deployment:

- Use **Azure Bastion** for secure SSH/RDP access without assigning
  the VM a public IP.
- Or disable port 22 entirely and use short-lived, token-based
  (JWT / OAuth) access requests for admin tasks.
- Place a **Load Balancer** in front of multiple VM instances to
  split traffic and remove any single point of failure.

## Mistakes Made and Resolved

- **Curly quotes / em-dashes** — writing commands inside the Mac
  Notes app auto-converted straight quotes (`"`) into curly quotes
  (`“ ”`) and double-hyphens (`--`) into em-dashes (`—`), silently
  breaking every affected flag. Resolved by switching to a plain-text
  code editor (VS Code), which never auto-formats these characters.
- **Missing `#` on continuation lines** — when commenting out a
  multi-line `az` command to avoid re-running it, only commenting the
  first line left the remaining lines as broken, standalone commands.
  Resolved using Vim visual-block mode (`Ctrl+Q` → select lines →
  `Shift+I` → `#` → `Esc`) to comment every line of a block at once.
- **Empty variables outside the script** — `$RG` / `$VMNAME` only
  exist for the lifetime of the script's own process. Running an `az`
  command directly in the terminal (outside `deploy.sh`) using those
  variable names silently passed empty strings, producing a confusing
  "resource not found" API error.
- **Missing `-y` flag on `apt install`** — without it, the install
  hung indefinitely waiting for a y/n confirmation prompt that no one
  was present to answer, since `run-command` executes unattended on
  the remote VM.

## Key Learnings

- `az group create` is idempotent — safe to re-run. `az vm create` is
  **not** — re-running it against an existing VM risks conflicts or
  orphaned resources (a NIC or disk left behind from a failed
  attempt). This is exactly the class of problem Infrastructure-as-
  Code tools like Terraform solve, by tracking actual vs. desired
  state instead of blindly re-running imperative create commands.
- Resource names are not portable across re-runs in the same
  subscription. Hardcoded names like `rg-p2-001` would collide if a
  second engineer, or I, ran the script again. True re-usability
  needs either parameterized names (script arguments) or idempotency
  checks, e.g. `az vm show ... || az vm create ...`.
- Scripting with CLI forces you to see the full dependency chain
  (RG → VNet → NIC → VM) that the Portal wizard hides behind one
  "Create" button — this is the deeper value of automation, beyond
  just speed.

## Verification

| Check | Status |
|---|---|
| Resource Group created and verified in Portal | ✅ |
| VNet (`10.0.0.0/16`) and Subnet (`10.0.1.0/24`) verified in Portal | ✅ |
| VM created — private IP `10.0.1.4` confirmed inside correct subnet | ✅ |
| NSG rules restricted to ports 22 and 80 only, verified | ✅ |
| Apache installed and running | ✅ |
| Public IP printed by script | ✅ |
| `curl http://<public-ip>` returned Apache2 Ubuntu default page | ✅ |
| Browser verification of Apache default page | ✅ |

## Files in This Repo

```
OPS-CLOUD-P2-001/
├── deploy.sh                                       # full automation script
├── README.md                                       # this file
├── OPS-CLOUD-P2-001-Documentation.docx             # formatted write-up (screenshots embedded)
└── screenshots/
    ├── OPS-CLOUD-P2-001-RG.png
    ├── OPS-CLOUD-P2-001-Vnet.png
    ├── OPS-CLOUD-P2-001-VM.png
    ├── OPS-CLOUD-P2-001-Install_Apache_remotely.png
    └── OPS-CLOUD-P2-001-Apache_server.png
```

- `deploy.sh` — full automation script (RG → VNet → VM → NSG → Apache → IP)
- `README.md` — this file
- `OPS-CLOUD-P2-001-Documentation.docx` — formatted project write-up with
  all screenshots embedded inline
- `screenshots/` — raw Portal/terminal verification evidence:
  - **OPS-CLOUD-P2-001-RG.png** — `rg-p2-001` resource group, Australia East
  - **OPS-CLOUD-P2-001-Vnet.png** — VNet `10.0.0.0/16` with subnet `10.0.1.0/24`
  - **OPS-CLOUD-P2-001-VM.png** — VM running, private IP `10.0.1.4` inside
    the correct subnet
  - **OPS-CLOUD-P2-001-Install_Apache_remotely.png** — `az vm run-command`
    output confirming Apache install succeeded
  - **OPS-CLOUD-P2-001-Apache_server.png** — browser confirmation of the
    Apache2 Ubuntu default page at the public IP
