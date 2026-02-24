# Kubernetes Terraform Platform

A modular Terraform infrastructure platform for deploying and managing essential services on Kubernetes clusters. Designed for flexibility with YAML-driven configuration, multi-environment support, and easy extensibility.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Ingress NGINX│  │ Cert Manager │  │ Namespaces           │  │
│  │  (Gateway)   │  │  (TLS/Certs) │  │  (Resource Isolation)│  │
│  └──────┬───────┘  └──────────────┘  └──────────────────────┘  │
│         │                                                       │
│  ┌──────┴───────────────────────────────────────────────────┐   │
│  │                    Ingress Routes                        │   │
│  ├──────────┬──────────┬──────────┬──────────┬─────────────┤   │
│  │          │          │          │          │             │   │
│  ▼          ▼          ▼          ▼          ▼             ▼   │
│ ┌────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────────┐│
│ │Vault│  │Open  │  │ n8n  │  │Grafana│  │ArgoCD│  │   Your   ││
│ │     │  │WebUI │  │      │  │      │  │      │  │   App    ││
│ └────┘  └──────┘  └──────┘  └──────┘  └──────┘  └──────────┘│
│                                  │                            │
│  ┌────────────────────────────────────────────────────────┐   │
│  │              Data & Infrastructure Layer               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐   │   │
│  │  │PostgreSQL│  │  Redis   │  │Prometheus + Grafana│   │   │
│  │  │ (Database)│  │ (Cache)  │  │   (Monitoring)     │   │   │
│  │  └──────────┘  └──────────┘  └────────────────────┘   │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

Managed by Terraform + Helm │ Config via YAML values files
```

## Applications & Services

| Application              | Description                               | Default (Dev) | Helm Chart Version |
| ------------------------ | ----------------------------------------- | :-----------: | :----------------: |
| **Ingress NGINX**        | Ingress controller for HTTP/HTTPS routing |    Enabled    |       4.14.3       |
| **Cert Manager**         | Automated TLS certificate management      |    Enabled    |      v1.17.1       |
| **HashiCorp Vault**      | Secrets management and encryption         |    Enabled    |       0.30.0       |
| **PostgreSQL**           | Relational database (Bitnami)             |    Enabled    |       16.6.7       |
| **Open WebUI**           | Web interface for AI chat applications    |    Enabled    |       6.11.0       |
| **n8n**                  | Workflow automation platform              |    Enabled    |       1.5.10       |
| **Prometheus + Grafana** | Monitoring and observability stack        |   Disabled    |       82.2.0       |
| **ArgoCD**               | GitOps continuous delivery                |   Disabled    |       9.4.3        |
| **Redis**                | In-memory cache and data store            |   Disabled    |      20.11.3       |

## Prerequisites

- Kubernetes cluster (Docker Desktop, minikube, EKS, GKE, AKS, or any distribution)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.7
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured with cluster access

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/razvanmacovei/k8s-terraform-platform.git
cd k8s-terraform-platform
cp .env.example .env
# Edit .env with your actual credentials
```

### 2. Deploy

```bash
# Using Make
make init
make apply ENV=docker-desktop

# Or using the setup script
chmod +x setup.sh
./setup.sh values/docker-desktop.yaml
```

### 3. Access your services

| Service    | URL                                                 |
| ---------- | --------------------------------------------------- |
| Vault      | https://vault.localhost                             |
| Open WebUI | https://chat.localhost                              |
| n8n        | https://n8n.localhost                               |
| Grafana    | https://grafana.localhost (when monitoring enabled) |
| ArgoCD     | https://argocd.localhost (when ArgoCD enabled)      |

Vault is automatically initialized and unsealed during deploy. Retrieve credentials with:

```bash
terraform -chdir=./modules output -raw vault_root_token
terraform -chdir=./modules output -raw vault_unseal_keys
```

## Multi-Environment Support

The platform includes pre-configured values files for different environments:

| Environment    | Values File                  | Description                                              |
| -------------- | ---------------------------- | -------------------------------------------------------- |
| **Dev**        | `values/docker-desktop.yaml` | Local development with minimal resources                 |
| **Staging**    | `values/staging.yaml`        | Pre-production with moderate resources and monitoring    |
| **Production** | `values/production.yaml`     | Full HA setup with replicas, autoscaling, and monitoring |

```bash
# Deploy to specific environments
make apply ENV=docker-desktop    # Local development
make apply ENV=staging           # Staging environment
make apply ENV=production        # Production (with confirmation prompt)

# Or with setup.sh
./setup.sh values/staging.yaml
./setup.sh values/production.yaml
```

To add a custom environment, create a new values file (e.g. `values/my-env.yaml`) and use it directly:

```bash
make apply ENV=my-env
```

## Configuration

### Enabling/Disabling Services

Toggle any service by setting `enabled: true/false` in your values file:

```yaml
monitoring:
  enabled: true # Enable the Prometheus + Grafana stack

argocd:
  enabled: false # Disable ArgoCD

redis:
  enabled: true # Enable Redis cache
```

### Adding New Applications

1. Create a Terraform file in `modules/`:

```hcl
resource "helm_release" "myapp" {
  count      = lookup(local.values, "myapp", null) != null ? (lookup(local.values.myapp, "enabled", false) == true ? 1 : 0) : 0
  name       = local.values.myapp.name
  namespace  = local.values.myapp.namespace
  repository = local.values.myapp.repository
  chart      = local.values.myapp.chart
  version    = local.values.myapp.version

  values = [yamlencode(local.values.myapp.values)]

  wait          = true
  wait_for_jobs = true
}
```

2. Add the configuration to your values file:

```yaml
namespaces:
  - myapp # Add the namespace

myapp:
  enabled: true
  name: myapp
  namespace: myapp
  chart: myapp-chart
  version: 1.0.0
  repository: https://charts.example.com
  values:
    # Application-specific Helm values
```

### Remote State Backend

The `backends/` directory contains examples for configuring remote state:

- `backends/s3.tf.example` - AWS S3 backend
- `backends/gcs.tf.example` - Google Cloud Storage backend
- `backends/azurerm.tf.example` - Azure Storage backend

Copy the relevant example into `modules/providers.tf` and configure with your credentials.

## Usage Reference

### Setup Script

```bash
./setup.sh [options] <values_file> [destroy]

Options:
  -k PATH   Kubeconfig file path    (default: ~/.kube/config)
  -e PATH   Environment file path   (default: .env)
  -m PATH   Terraform modules dir   (default: ./modules)
  -s        Skip post-deploy health checks
  -h        Show help

Examples:
  ./setup.sh values/docker-desktop.yaml            # Deploy dev
  ./setup.sh -k ~/.kube/prod values/production.yaml # Deploy with custom kubeconfig
  ./setup.sh values/staging.yaml destroy            # Tear down staging
```

### Makefile Commands

```bash
# Terraform workflow (ENV required)
make plan ENV=docker-desktop       # Plan changes
make apply ENV=staging             # Apply changes
make destroy ENV=production        # Destroy infrastructure (production requires confirmation)

# Utilities
make help                          # Show all available commands
make init                          # Initialize Terraform
make list                          # List available environments
make fmt                           # Format Terraform files
make validate                      # Validate configuration
make lint                          # Run TFLint
make clean                         # Clean Terraform cache
make status                        # Show current state
make output                        # Show Terraform outputs
```

### Manual Terraform

```bash
terraform -chdir=modules init
terraform -chdir=modules plan  -var="values_path=values/docker-desktop.yaml"
terraform -chdir=modules apply -var="values_path=values/docker-desktop.yaml" -auto-approve
```

## CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/terraform-validate.yml`) that runs on every push and PR to `main`:

- **Terraform format check** - Ensures consistent code formatting
- **Terraform validate** - Validates configuration syntax
- **TFLint** - Lints Terraform code for best practices
- **tfsec** - Scans for security misconfigurations
- **Values validation** - Validates all YAML values files have required structure

## Project Structure

```
k8s-terraform-platform/
├── .github/
│   └── workflows/
│       └── terraform-validate.yml    # CI/CD pipeline
├── backends/
│   ├── s3.tf.example                 # AWS S3 backend config
│   ├── gcs.tf.example                # GCP GCS backend config
│   └── azurerm.tf.example            # Azure backend config
├── modules/
│   ├── providers.tf                  # Terraform & provider config
│   ├── variables.tf                  # Input variables with validation
│   ├── locals.tf                     # Local values (YAML loading)
│   ├── main.tf                       # Main configuration
│   ├── namespaces.tf                 # Kubernetes namespaces
│   ├── ingress-nginx.tf              # Ingress NGINX controller
│   ├── cert-manager.tf               # Certificate management
│   ├── vault.tf                      # HashiCorp Vault
│   ├── postgresql.tf                 # PostgreSQL database
│   ├── open_webui.tf                 # Open WebUI
│   ├── n8n.tf                        # n8n workflow automation
│   ├── monitoring.tf                 # Prometheus + Grafana stack
│   ├── argocd.tf                     # ArgoCD GitOps
│   ├── redis.tf                      # Redis cache
│   ├── apps.tf                       # Shared Helm repo management
│   └── outputs.tf                    # Output values
├── scripts/
│   └── vault-init-unseal.sh          # Vault auto-init & unseal
├── values/
│   ├── docker-desktop.yaml           # Dev environment config
│   ├── staging.yaml                  # Staging environment config
│   └── production.yaml               # Production environment config
├── .env.example                      # Environment variable template
├── .gitignore                        # Git ignore rules
├── Makefile                          # Make targets for common ops
├── setup.sh                          # Automated setup script
└── README.md                         # This file
```

## Cleanup

```bash
# Destroy specific environment
make destroy ENV=docker-desktop
make destroy ENV=staging
make destroy ENV=production        # Requires typing confirmation

# Or using setup.sh
./setup.sh values/docker-desktop.yaml destroy
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Run `make fmt` and `make validate` before committing
4. Submit a Pull Request

## License

This project is licensed under the [Apache License 2.0](LICENSE). See individual Helm chart licenses for third-party components.
