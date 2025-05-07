# Main configuration for apps module
# Common logic for all applications

# This file can be used for shared resources or utilities across applications
# Each application has its own dedicated .tf file with specific configurations

# Add Helm repository for Open WebUI
resource "null_resource" "add_open_webui_repo" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "helm repo add open-webui https://helm.openwebui.com/"
  }
} 