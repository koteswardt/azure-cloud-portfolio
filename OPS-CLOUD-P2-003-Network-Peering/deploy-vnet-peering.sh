#! /bin/bash

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
VNET1_ID="/subscriptions/d84ef03e-6d2f-4b85-a00f-a13a7ed1d4bb/resourceGroups/OPS-CLOUD-P2-003-RG/providers/Microsoft.Network/virtualNetworks/OPS-CLOUD-P2-003-Vnet1"
VNET2_ID="/subscriptions/d84ef03e-6d2f-4b85-a00f-a13a7ed1d4bb/resourceGroups/OPS-CLOUD-P2-003-RG/providers/Microsoft.Network/virtualNetworks/OPS-CLOUD-P2-003-Vnet2"


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