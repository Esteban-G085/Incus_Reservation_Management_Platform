terraform {
  required_version = ">= 1.6.0"
  required_providers {
    incus = {
      source  = "registry.opentofu.org/lxc/incus"
      version = "~> 0.3"
    }
  }
}
