#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Colors & helpers
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

###############################################################################
# Usage & CLI parsing
###############################################################################
show_usage() {
  cat <<EOF
Usage: $0 [-k kubeconfig_path] [-e env_file_path] [-m modules_dir] [-s] <values_file_path> [destroy]

Arguments:
  -k kubeconfig_path  Path to the kubeconfig file      (default: ~/.kube/config)
  -e env_file_path    Path to the .env file            (default: .env)
  -m modules_dir      Directory where *.tf files live  (default: ./modules)
  -s                  Skip health checks after apply
  values_file_path    Path to the values YAML file     (e.g., values/docker-desktop.yaml)
  destroy             Optional: add this word to destroy the infrastructure

Examples:
  $0 values/docker-desktop.yaml
  $0 -k ~/.kube/devconfig values/docker-desktop.yaml
  $0 values/docker-desktop.yaml destroy
  $0 -s values/docker-desktop.yaml
EOF
  exit 1
}

# Defaults
KUBECONFIG_PATH="$HOME/.kube/config"
ENV_FILE_PATH=".env"
MODULES_DIR="./modules"
SKIP_HEALTH_CHECK=false

while getopts "k:e:m:sh" opt; do
  case $opt in
    k) KUBECONFIG_PATH="$OPTARG" ;;
    e) ENV_FILE_PATH="$OPTARG" ;;
    m) MODULES_DIR="$OPTARG" ;;
    s) SKIP_HEALTH_CHECK=true ;;
    h) show_usage ;;
    *) show_usage ;;
  esac
done
shift $((OPTIND-1))

[[ $# -lt 1 ]] && show_usage
VALUES_PATH=$1
ACTION=${2:-apply}

###############################################################################
# Pre-flight checks
###############################################################################
log "Running pre-flight checks..."

check_command() {
  if ! command -v "$1" &> /dev/null; then
    error "$1 is not installed. Please install it first."
    exit 1
  fi
  ok "$1 found: $(command -v "$1")"
}

check_command terraform
check_command kubectl
check_command helm

[[ -f "$VALUES_PATH"     ]] || { error "Values file '$VALUES_PATH' not found!";     exit 1; }
[[ -f "$KUBECONFIG_PATH" ]] || { error "Kubeconfig '$KUBECONFIG_PATH' not found!";  exit 1; }
[[ -d "$MODULES_DIR"     ]] || { error "Modules dir '$MODULES_DIR' not found!";     exit 1; }

ok "Values file: $VALUES_PATH"
ok "Kubeconfig:  $KUBECONFIG_PATH"
ok "Modules dir: $MODULES_DIR"

export KUBECONFIG="$KUBECONFIG_PATH"

# Verify cluster connectivity
log "Verifying cluster connectivity..."
if kubectl cluster-info &>/dev/null; then
  ok "Cluster is reachable"
else
  error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
  exit 1
fi

###############################################################################
# .env -> shell -> TF_VAR_*
###############################################################################
if [[ -f "$ENV_FILE_PATH" ]]; then
  log "Loading variables from $ENV_FILE_PATH"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ $key =~ ^#.*$ || -z $key ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    value=${value//\"/} ; value=${value//\'/}
    export "TF_VAR_${key}=${value}"
  done < "$ENV_FILE_PATH"
  ok "Environment variables loaded"
else
  warn "'$ENV_FILE_PATH' not found, relying on existing env vars."
fi

###############################################################################
# Helper for consistent TF calls
###############################################################################
tf() { terraform -chdir="$MODULES_DIR" "$@"; }

###############################################################################
# Terraform workflow
###############################################################################
if [[ ! -d "$MODULES_DIR/.terraform" ]]; then
  log "Initializing Terraform in $MODULES_DIR"
  tf init
  ok "Terraform initialized"
fi

if [[ "$ACTION" == "destroy" ]]; then
  warn "Planning DESTRUCTION of infrastructure"
  tf plan -destroy -var="values_path=$VALUES_PATH"
  echo ""
  warn "Destroying infrastructure..."
  tf destroy -var="values_path=$VALUES_PATH" -auto-approve
  ok "Infrastructure destroyed"
else
  log "Planning changes"
  tf plan -var="values_path=$VALUES_PATH"
  echo ""
  log "Applying changes..."
  tf apply -var="values_path=$VALUES_PATH" -auto-approve
  ok "Terraform apply completed"

  ###########################################################################
  # Post-deploy health checks
  ###########################################################################
  if [[ "$SKIP_HEALTH_CHECK" == false ]]; then
    echo ""
    log "Running post-deployment health checks..."

    check_namespace() {
      local ns=$1
      if kubectl get namespace "$ns" &>/dev/null; then
        local pods_total
        local pods_ready
        pods_total=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
        pods_ready=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running\|Completed" || true)
        if [[ "$pods_total" -eq 0 ]]; then
          warn "$ns: no pods found"
        elif [[ "$pods_ready" -eq "$pods_total" ]]; then
          ok "$ns: $pods_ready/$pods_total pods ready"
        else
          warn "$ns: $pods_ready/$pods_total pods ready"
        fi
      fi
    }

    # Extract namespaces from values file
    if command -v python3 &>/dev/null; then
      namespaces=$(python3 -c "
import yaml
with open('$VALUES_PATH') as f:
    data = yaml.safe_load(f)
for ns in data.get('namespaces', []):
    print(ns)
" 2>/dev/null || true)
    else
      namespaces=$(grep '^\s*-\s' "$VALUES_PATH" | head -20 | sed 's/.*-\s*//')
    fi

    for ns in $namespaces; do
      check_namespace "$ns"
    done

    echo ""
    log "Ingress endpoints:"
    kubectl get ingress -A --no-headers 2>/dev/null | while read -r ns name _ hosts _rest; do
      ok "  $ns/$name -> $hosts"
    done || warn "No ingress resources found"
  fi
fi

echo ""
ok "All done!"
