#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Usage & CLI parsing
###############################################################################
show_usage() {
  cat <<EOF
Usage: $0 [-k kubeconfig_path] [-e env_file_path] [-m modules_dir] <values_file_path> [destroy]

Arguments:
  -k kubeconfig_path  Path to the kubeconfig file      (default: ~/.kube/config)
  -e env_file_path    Path to the .env file            (default: .env)
  -m modules_dir      Directory where *.tf files live  (default: ./modules)
  values_file_path    Path to the values YAML file     (e.g., values/docker-desktop.yaml)
  destroy             Optional: add this word to destroy the infrastructure

Examples:
  $0 values/docker-desktop.yaml
  $0 -k ~/.kube/devconfig -m infra modules/dev values/docker-desktop.yaml destroy
EOF
  exit 1
}

# Defaults
KUBECONFIG_PATH="$HOME/.kube/config"
ENV_FILE_PATH=".env"
MODULES_DIR="./modules"

while getopts "k:e:m:" opt; do
  case $opt in
    k) KUBECONFIG_PATH="$OPTARG" ;;
    e) ENV_FILE_PATH="$OPTARG" ;;
    m) MODULES_DIR="$OPTARG" ;;
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
[[ -f "$VALUES_PATH"      ]] || { echo "Values file '$VALUES_PATH' not found!"      ; exit 1; }
[[ -f "$KUBECONFIG_PATH"  ]] || { echo "Kubeconfig '$KUBECONFIG_PATH' not found!"  ; exit 1; }
[[ -d "$MODULES_DIR"      ]] || { echo "Modules dir '$MODULES_DIR' not found!"     ; exit 1; }

export KUBECONFIG="$KUBECONFIG_PATH"

###############################################################################
# .env  shell  TF_VAR_*
###############################################################################
if [[ -f "$ENV_FILE_PATH" ]]; then
  echo "Loading variables from $ENV_FILE_PATH"
  set -o allexport
  source "$ENV_FILE_PATH"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ $key =~ ^#.*$ || -z $key ]] && continue           # skip comments / blanks
    value=${value//\"/} ; value=${value//\'/}            # strip quotes
    export "TF_VAR_${key}=${value}"
  done < "$ENV_FILE_PATH"
  set +o allexport
else
  echo "Warning: '$ENV_FILE_PATH' not found, relying on existing env vars."
fi

###############################################################################
# Helper for consistent TF calls
###############################################################################
tf() { terraform -chdir="$MODULES_DIR" "$@"; }

###############################################################################
# Terraform workflow
###############################################################################
if [[ ! -d "$MODULES_DIR/.terraform" ]]; then
  echo "Initializing Terraform in $MODULES_DIR"
  tf init
fi

if [[ "$ACTION" == "destroy" ]]; then
  echo "Planning destruction"
  tf plan  -destroy -var="values_path=$VALUES_PATH"
  echo "Destroying"
  tf destroy        -var="values_path=$VALUES_PATH" -auto-approve
else
  echo "Planning changes"
  tf plan  -var="values_path=$VALUES_PATH"
  echo "Applying"
  tf apply -var="values_path=$VALUES_PATH" -auto-approve
fi

echo " All done"
