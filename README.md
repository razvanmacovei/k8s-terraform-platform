# Kubernetes Terraform Platform

## Overview

This project provides a modular Terraform infrastructure for deploying and managing essential services on Kubernetes clusters. It was designed with flexibility in mind, allowing users to easily enable or disable components through YAML configuration files. While primarily tested with Docker Desktop's Kubernetes, it can be adapted for other Kubernetes environments.

## Applications & Services

| Application | Description | Default Status |
|-------------|-------------|----------------|
| Ingress NGINX | NGINX-based Ingress controller for Kubernetes | Enabled |
| Cert Manager | Certificate management for Kubernetes | Enabled |
| Vault | Secrets management solution | Enabled |
| PostgreSQL | PostgreSQL database | Enabled |
| Open WebUI | Web interface for AI chat applications | Enabled |
| Custom Namespaces | Organized resource isolation | Enabled |

## Prerequisites

- Kubernetes cluster (Docker Desktop, minikube, or any other distribution)
- Terraform (v1.0.0 or higher)
- Helm (v3.0.0 or higher)
- kubectl configured with access to your cluster

## Getting Started

### Quick Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/razvanmacovei/k8s-terraform-platform.git
   cd k8s-terraform-platform
   ```

2. Make the setup script executable:

   ```bash
   chmod +x setup.sh
   ```

3. Create a copy of the example environment file and fill in your secrets:
   
   ```
   cp .env.example .env
   # then edit .env with real values
   ```

4. Run the setup script:

   ```bash
   # Using default kubeconfig (~/.kube/config)
   ./setup.sh values/docker-desktop.yaml

   # Using a custom kubeconfig file
   ./setup.sh -k /path/to/your/kubeconfig values/docker-desktop.yaml
   ```

### Manual Setup

If you prefer to run commands manually:

1. Initialize Terraform:

   ```bash
   terraform init
   ```

2. Copy .env.example to .env and update the placeholders:

   ```
   cp .env.example .env
   ```

3. Set your kubeconfig:

   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig
   ```

4. Plan the changes:

   ```bash
   terraform plan -var="values_path=values/docker-desktop.yaml"
   ```

5. Apply the configuration:
   ```bash
   terraform apply -var="values_path=values/docker-desktop.yaml" -auto-approve
   ```

## Configuration

### Customizing Deployments

The platform uses a values-based configuration approach. All settings are defined in YAML files in the `values/` directory.

To enable or disable specific applications, modify the `enabled` flag for each component in your values file:

```yaml
ingress_nginx:
  enabled: true  # Set to false to disable
  # other configuration...

postgresql:
  enabled: false  # Disabled component
  # other configuration...
```

### Adding New Applications

To add a new application:

1. Create a new Terraform file (e.g., `newapp.tf`) in the `modules/apps` directory following this pattern:

```hcl
resource "helm_release" "newapp" {
  count      = lookup(local.values.newapp, "enabled", false) == true ? 1 : 0
  name       = local.values.newapp.name
  namespace  = local.values.newapp.namespace
  repository = local.values.newapp.repository
  chart      = local.values.newapp.chart
  version    = local.values.newapp.version

  values = [yamlencode(local.values.newapp.values)]

  depends_on = [kubernetes_namespace.namespaces]
}
```

2. Add the application configuration to your values file:

```yaml
newapp:
  enabled: true
  name: newapp
  namespace: newapp
  chart: newapp
  version: 1.0.0
  repository: https://charts.example.com
  values:
    # Application-specific values
```

3. Add the namespace to the namespaces list in your values file:

```yaml
namespaces:
  - ingress-nginx
  - cert-manager
  - newapp
```

## Post-Installation

After installing the components, you can access applications using the configured ingress hosts:

- Vault: https://vault.localhost (default)
- Open WebUI: https://chat.localhost (default)

## Cleanup

To remove all created resources:

```bash
# Using default kubeconfig
./setup.sh values/docker-desktop.yaml destroy

# Using a custom kubeconfig file
./setup.sh -k /path/to/your/kubeconfig values/docker-desktop.yaml destroy
```

Or manually:

```bash
terraform destroy -var="values_path=values/docker-desktop.yaml" -auto-approve
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
