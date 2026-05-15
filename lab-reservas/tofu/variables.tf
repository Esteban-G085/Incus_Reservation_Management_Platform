# =============================================================================
# variables.tf — Configuración centralizada del laboratorio
# =============================================================================

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "lab-reservas"
}

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------
variable "network_name" {
  description = "Nombre de la red OVN"
  type        = string
  default     = "lab-net"
}

variable "network_cidr" {
  description = "Rango CIDR de la red OVN"
  type        = string
  default     = "10.10.0.0/24"
}

variable "uplink_bridge" {
  description = "Bridge uplink para OVN"
  type        = string
  default     = "incusbr0"
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
variable "storage_pool" {
  description = "Pool de almacenamiento"
  type        = string
  default     = "default"
}

variable "storage_pool_driver" {
  description = "Driver del storage pool"
  type        = string
  default     = "dir"
}

# ---------------------------------------------------------------------------
# Imagen base
# ---------------------------------------------------------------------------
variable "image" {
  description = "Imagen base de los contenedores"
  type        = string
  default     = "images:debian/13"
}

# ---------------------------------------------------------------------------
# Definición de nodos
# ---------------------------------------------------------------------------
variable "nodes" {
  description = "Mapa de nodos con sus recursos"
  type = map(object({
    cpu    = number
    memory = string
    disk   = string
    ip     = string
  }))

  default = {
    node-control = { cpu = 1, memory = "256MiB",  disk = "4GiB",  ip = "10.10.0.2" }
    app-api      = { cpu = 1, memory = "768MiB",  disk = "8GiB",  ip = "10.10.0.3" }
    app-core     = { cpu = 1, memory = "768MiB",  disk = "8GiB",  ip = "10.10.0.4" }
    db-postgres  = { cpu = 2, memory = "2GiB",    disk = "20GiB", ip = "10.10.0.5" }
    monitoring   = { cpu = 2, memory = "1536MiB", disk = "10GiB", ip = "10.10.0.6" }
    ceph-node    = { cpu = 1, memory = "512MiB",  disk = "15GiB", ip = "10.10.0.7" }
  }
}

# ---------------------------------------------------------------------------
# Volúmenes persistentes
# ---------------------------------------------------------------------------
variable "volumes" {
  description = "Lista de volúmenes persistentes"
  type        = list(string)
  default     = [
    "postgres-data",
    "prometheus-data",
    "grafana-data",
    "ceph-data",
    "app-data",
  ]
}
