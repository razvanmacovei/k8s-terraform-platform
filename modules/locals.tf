locals {
  values = yamldecode(file("${path.module}/../${var.values_path}"))
} 