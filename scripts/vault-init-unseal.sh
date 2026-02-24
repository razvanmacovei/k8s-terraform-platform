#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Vault Init & Unseal Script
#
# Called by Terraform null_resource after helm_release.vault deploys.
# Receives configuration via environment variables set by local-exec.
#
# Required env vars:
#   VAULT_NAMESPACE       - Kubernetes namespace (e.g. "vault")
#   VAULT_KEY_SHARES      - Number of Shamir key shares
#   VAULT_KEY_THRESHOLD   - Number of keys needed to unseal
#   VAULT_SECRET_NAME     - K8s Secret name to store credentials
#
# Optional env vars:
#   VAULT_POD_PREFIX      - Pod name prefix (default: "vault")
#   VAULT_HA_ENABLED      - "true" if HA mode (default: "false")
#   VAULT_HA_REPLICAS     - Number of HA replicas (default: 1)
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[vault-init]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[vault-init]${NC}  $*"; }
error() { echo -e "${RED}[vault-init]${NC}  $*" >&2; }
ok()    { echo -e "${GREEN}[vault-init]${NC}  $*"; }

# Read config from env (set by Terraform local-exec)
NAMESPACE="${VAULT_NAMESPACE:?VAULT_NAMESPACE is required}"
KEY_SHARES="${VAULT_KEY_SHARES:?VAULT_KEY_SHARES is required}"
KEY_THRESHOLD="${VAULT_KEY_THRESHOLD:?VAULT_KEY_THRESHOLD is required}"
SECRET_NAME="${VAULT_SECRET_NAME:?VAULT_SECRET_NAME is required}"
POD_PREFIX="${VAULT_POD_PREFIX:-vault}"
HA_ENABLED="${VAULT_HA_ENABLED:-false}"
HA_REPLICAS="${VAULT_HA_REPLICAS:-1}"

LEADER_POD="${POD_PREFIX}-0"
MAX_WAIT=300  # 5 minutes
POLL_INTERVAL=5

###############################################################################
# Helpers
###############################################################################

# Run vault CLI inside the leader pod
vault_exec() {
  kubectl exec "${LEADER_POD}" -n "${NAMESPACE}" -- vault "$@" 2>/dev/null
}

# Run vault CLI inside a specific pod
vault_exec_pod() {
  local pod=$1; shift
  kubectl exec "${pod}" -n "${NAMESPACE}" -- vault "$@" 2>/dev/null
}

# Wait for a pod to be Running
wait_for_pod() {
  local pod=$1
  local elapsed=0
  log "Waiting for pod ${pod} to be Running (up to ${MAX_WAIT}s)..."
  while true; do
    local phase
    phase=$(kubectl get pod "${pod}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [[ "${phase}" == "Running" ]]; then
      ok "Pod ${pod} is Running"
      return 0
    fi
    if [[ ${elapsed} -ge ${MAX_WAIT} ]]; then
      error "Timed out waiting for pod ${pod} (status: ${phase})"
      return 1
    fi
    sleep "${POLL_INTERVAL}"
    elapsed=$((elapsed + POLL_INTERVAL))
  done
}

# Check if Vault is initialized
is_initialized() {
  local status_json
  status_json=$(vault_exec status -format=json 2>/dev/null || true)
  if [[ -z "${status_json}" ]]; then
    return 1
  fi
  local initialized
  initialized=$(echo "${status_json}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('initialized', False))" 2>/dev/null || echo "False")
  [[ "${initialized}" == "True" ]]
}

# Check if Vault is sealed
is_sealed() {
  local status_json
  status_json=$(vault_exec status -format=json 2>/dev/null || true)
  if [[ -z "${status_json}" ]]; then
    return 0  # assume sealed if we can't reach it
  fi
  local sealed
  sealed=$(echo "${status_json}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "True")
  [[ "${sealed}" == "True" ]]
}

# Store credentials in a Kubernetes Secret
store_credentials() {
  local root_token=$1
  local unseal_keys_json=$2

  log "Storing credentials in K8s Secret ${SECRET_NAME}..."

  # Build --from-literal args for each unseal key
  local secret_args=()
  secret_args+=("--from-literal=root-token=${root_token}")
  secret_args+=("--from-literal=unseal-keys-json=${unseal_keys_json}")

  local key_count
  key_count=$(echo "${unseal_keys_json}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  for ((i=0; i<key_count; i++)); do
    local key
    key=$(echo "${unseal_keys_json}" | python3 -c "import sys,json; print(json.load(sys.stdin)[${i}])")
    secret_args+=("--from-literal=unseal-key-${i}=${key}")
  done

  # Delete existing secret if present, then create
  kubectl delete secret "${SECRET_NAME}" -n "${NAMESPACE}" --ignore-not-found
  kubectl create secret generic "${SECRET_NAME}" -n "${NAMESPACE}" "${secret_args[@]}"
  ok "Credentials stored in secret ${NAMESPACE}/${SECRET_NAME}"
}

# Load unseal keys from existing K8s Secret
load_unseal_keys() {
  local keys_json
  keys_json=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.unseal-keys-json}' 2>/dev/null | base64 -d)
  echo "${keys_json}"
}

# Unseal a single Vault pod using the stored keys
unseal_pod() {
  local pod=$1
  local unseal_keys_json=$2

  local key_count
  key_count=$(echo "${unseal_keys_json}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  log "Unsealing ${pod} (need ${KEY_THRESHOLD} of ${key_count} keys)..."
  for ((i=0; i<KEY_THRESHOLD; i++)); do
    local key
    key=$(echo "${unseal_keys_json}" | python3 -c "import sys,json; print(json.load(sys.stdin)[${i}])")
    vault_exec_pod "${pod}" operator unseal "${key}" > /dev/null
  done
  ok "Pod ${pod} unsealed"
}

###############################################################################
# Main
###############################################################################

log "Starting Vault init/unseal (namespace=${NAMESPACE}, shares=${KEY_SHARES}, threshold=${KEY_THRESHOLD})"

# Step 1: Wait for leader pod
wait_for_pod "${LEADER_POD}"

# Step 2: Check initialization status
if is_initialized; then
  log "Vault is already initialized"

  if is_sealed; then
    log "Vault is sealed, loading keys from existing secret..."
    UNSEAL_KEYS_JSON=$(load_unseal_keys)
    if [[ -z "${UNSEAL_KEYS_JSON}" || "${UNSEAL_KEYS_JSON}" == "null" ]]; then
      error "Cannot unseal: no unseal keys found in secret ${SECRET_NAME}"
      error "Manual intervention required."
      exit 1
    fi
    unseal_pod "${LEADER_POD}" "${UNSEAL_KEYS_JSON}"
  else
    ok "Vault is already initialized and unsealed — nothing to do"
  fi

  # Handle HA replicas if sealed
  if [[ "${HA_ENABLED}" == "true" && ${HA_REPLICAS} -gt 1 ]]; then
    UNSEAL_KEYS_JSON="${UNSEAL_KEYS_JSON:-$(load_unseal_keys)}"
    for ((r=1; r<HA_REPLICAS; r++)); do
      replica_pod="${POD_PREFIX}-${r}"
      wait_for_pod "${replica_pod}"

      replica_sealed=$(kubectl exec "${replica_pod}" -n "${NAMESPACE}" -- vault status -format=json 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "True")

      if [[ "${replica_sealed}" == "True" ]]; then
        unseal_pod "${replica_pod}" "${UNSEAL_KEYS_JSON}"
      else
        ok "Replica ${replica_pod} already unsealed"
      fi
    done
  fi

  exit 0
fi

# Step 3: Initialize Vault
log "Initializing Vault (key_shares=${KEY_SHARES}, key_threshold=${KEY_THRESHOLD})..."
INIT_OUTPUT=$(vault_exec operator init \
  -key-shares="${KEY_SHARES}" \
  -key-threshold="${KEY_THRESHOLD}" \
  -format=json)

ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['root_token'])")
UNSEAL_KEYS_JSON=$(echo "${INIT_OUTPUT}" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['unseal_keys_b64']))")

ok "Vault initialized (root token and ${KEY_SHARES} unseal keys generated)"

# Step 4: Unseal leader
unseal_pod "${LEADER_POD}" "${UNSEAL_KEYS_JSON}"

# Step 5: Store credentials
store_credentials "${ROOT_TOKEN}" "${UNSEAL_KEYS_JSON}"

# Step 6: Handle HA replicas
if [[ "${HA_ENABLED}" == "true" && ${HA_REPLICAS} -gt 1 ]]; then
  log "HA mode: joining and unsealing ${HA_REPLICAS} replicas..."
  for ((r=1; r<HA_REPLICAS; r++)); do
    replica_pod="${POD_PREFIX}-${r}"
    wait_for_pod "${replica_pod}"

    log "Joining ${replica_pod} to raft cluster..."
    vault_exec_pod "${replica_pod}" operator raft join "http://${LEADER_POD}.${POD_PREFIX}-internal:8200" || true

    unseal_pod "${replica_pod}" "${UNSEAL_KEYS_JSON}"
  done
  ok "All HA replicas joined and unsealed"
fi

ok "Vault init/unseal complete"
echo ""
log "Retrieve credentials with:"
log "  terraform -chdir=./modules output -raw vault_root_token"
log "  terraform -chdir=./modules output -raw vault_unseal_keys"
