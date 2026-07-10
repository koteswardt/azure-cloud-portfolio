#!/bin/bash
# ============================================================================
# OPS-CLOUD-P2-002 : Automate Blob Storage Static Site
# ----------------------------------------------------------------------------
# Deploys a PaaS static website using Azure Blob Storage — no VM, no VNet,
# no NSG. Azure manages the OS, scaling, and replication; this script only
# owns the resource config and the site content.
#
# Pipeline: Resource Group -> Storage Account -> Static Website Property
#           -> Upload index.html -> Public endpoint
#
# Idempotency note:
#   - az group create is safe to re-run (idempotent).
#   - az storage account create is safe to re-run against the SAME name/config;
#     it will not fail or duplicate. Changing config on a re-run may produce
#     inconsistent results — not a full idempotency guarantee.
# ============================================================================

set -euo pipefail  # Exit immediately on error, unset variable, or failed pipe

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
RG="rg-p2-002"                  # Resource group — logical container for this project
STGACCOUNT="p2mystorage1657"    # Storage account name (lowercase, no hyphens, globally unique)
MYLOC="australiaeast"           # Azure region (short-form, CLI-compatible)

# ---------------------------------------------------------------------------
# 1. Resource Group
# Container for every resource this script creates. Created first so
# every subsequent resource has somewhere to attach.
# ---------------------------------------------------------------------------
az group create \
    --name "$RG" \
    --location "$MYLOC"

# ---------------------------------------------------------------------------
# 2. Storage Account
# Standard_LRS chosen deliberately: this is a low-traffic internal static
# page, so single-datacenter redundancy is sufficient. GRS/ZRS would add
# cost without a matching availability requirement for this use case.
# ---------------------------------------------------------------------------
az storage account create \
    --name "$STGACCOUNT" \
    --resource-group "$RG" \
    --location "$MYLOC" \
    --sku Standard_LRS

# ---------------------------------------------------------------------------
# 3. Enable Static Website Hosting
# This is a PROPERTY UPDATE on the storage account, not a separate resource.
# Azure automatically provisions the $web (site content) and $logs
# (traffic logs) containers as a side effect — no manual container
# creation needed.
# ---------------------------------------------------------------------------
az storage blob service-properties update \
    --account-name "$STGACCOUNT" \
    --static-website \
    --index-document index.html \
    --auth-mode login

# ---------------------------------------------------------------------------
# 4. Upload index.html to $web
# NOTE on auth-mode:
#   --auth-mode login (Azure AD) is the preferred, keyless approach, but
#   requires the caller to hold an RBAC role (e.g. Storage Blob Data
#   Contributor) on this storage account. That role assignment failed in
#   this environment (Graph could not resolve the Microsoft/Gmail-based
#   account by email — see README "Problems Encountered").
#   --auth-mode key is used here as a pragmatic fallback. This uses the
#   storage account's master key, which grants full access to the entire
#   account, not just this container. Production follow-up: fix the RBAC
#   assignment (via --assignee-object-id) and switch back to --auth-mode
#   login, or retrieve the key from Key Vault instead of letting the CLI
#   query it live.
#
# NOTE on '$web':
#   Single-quoted deliberately — in bash, $web unquoted or double-quoted
#   would expand as an (empty/undefined) variable, silently passing an
#   empty container name to the CLI.
# ---------------------------------------------------------------------------
az storage blob upload \
    --account-name "$STGACCOUNT" \
    --container-name '$web' \
    --name index.html \
    --file index.html \
    --auth-mode key \
    --overwrite

# ---------------------------------------------------------------------------
# 5. Print the live site URL
# Queried dynamically rather than hardcoded — the endpoint is a property
# of the storage account, not something to assume or guess.
# ---------------------------------------------------------------------------
SITE_URL=$(az storage account show \
    --name "$STGACCOUNT" \
    --resource-group "$RG" \
    --query "primaryEndpoints.web" \
    --output tsv)

echo ""
echo "Deployment complete."
echo "Static site live at: $SITE_URL"