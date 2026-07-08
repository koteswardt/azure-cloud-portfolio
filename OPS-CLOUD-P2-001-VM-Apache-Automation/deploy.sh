#!/bin/bash

# ── Variables ──
RG="rg-p2-001"
Location="australiaeast"
MYVNET="OPS-CLOUD-P2-001-Vnet"
MYSUBNET="OPS-CLOUD-P2-001-subnet"
VMNAME="OPS-CLOUD-P2-001-VM"
VMImage="Ubuntu2204"
VMsize="Standard_B1s"

# ── Resource Group ──
az group create --name "$RG" --location "$Location"

# ── VNet + Subnet ──
az network vnet create \
  --resource-group "$RG" \
  --name "$MYVNET" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "$MYSUBNET" \
  --subnet-prefix "10.0.1.0/24" \
  --location "$Location"

# ── VM (SSH key auth, no passwords) ──
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

# ── Open port 80 (22 already open by default) ──
az vm open-port --resource-group "$RG" --name "$VMNAME" --port 80

# ── Install Apache remotely ──
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VMNAME" \
  --command-id RunShellScript \
  --scripts "sudo apt-get update && sudo apt-get install -y apache2"

# ── Print public IP ──
IP=$(az vm show -d --resource-group "$RG" --name "$VMNAME" --query publicIps -o tsv)
echo "Apache deployed. Visit: http://$IP"