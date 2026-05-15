# =============================================================================
# main.tf — Infraestructura gestionada por OpenTofu
# Nota: Redes y volúmenes existen pero no se gestionan aquí (creados en Etapa 1)
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Storage pool
# ---------------------------------------------------------------------------
resource "incus_storage_pool" "default" {
  name   = var.storage_pool
  driver = var.storage_pool_driver

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# 2. Perfiles de recursos (uno por nodo)
# ---------------------------------------------------------------------------
resource "incus_profile" "node" {
  for_each = var.nodes

  name = each.key

  config = {
    "limits.cpu"    = each.value.cpu
    "limits.memory" = each.value.memory
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = incus_storage_pool.default.name
      path = "/"
      size = each.value.disk
    }
  }
}

# ---------------------------------------------------------------------------
# 3. Contenedores
# ---------------------------------------------------------------------------
resource "incus_instance" "node" {
  for_each = var.nodes

  name      = each.key
  image     = var.image
  type      = "container"
  ephemeral = false

  profiles = [incus_profile.node[each.key].name]

  config = {
    "boot.autostart" = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "lab-net"
      name    = "eth0"
    }
  }

  depends_on = [
    incus_profile.node,
  ]
}