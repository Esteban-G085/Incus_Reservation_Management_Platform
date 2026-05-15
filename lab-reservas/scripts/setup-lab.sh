#!/bin/bash
# =============================================================================
# setup-lab.sh — Infraestructura base del laboratorio Incus (CORREGIDO)
# Proyecto: Plataforma de Gestión de Reservas
# Etapa 1: Red OVN + Perfiles + Volúmenes + Contenedores
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colores para output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

# -----------------------------------------------------------------------------
# Funciones de log
# -----------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $1${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# -----------------------------------------------------------------------------
# Limpieza en caso de fallo
# -----------------------------------------------------------------------------
cleanup() {
  log_error "Algo falló. Iniciando limpieza..."

  log_warn "Eliminando contenedores..."
  for container in node-control app-api app-core db-postgres monitoring ceph-node; do
    if sudo incus info "$container" &>/dev/null; then
      sudo incus delete "$container" --force 2>/dev/null && log_info "Eliminado: $container"
    fi
  done

  log_warn "Eliminando red OVN lab-net..."
  sudo incus network delete lab-net 2>/dev/null && log_info "Red lab-net eliminada" || true

  log_warn "Eliminando bridge incusbr0..."
  sudo incus network delete incusbr0 2>/dev/null && log_info "Bridge incusbr0 eliminado" || true

  log_warn "Eliminando perfiles..."
  for profile in node-control app-api app-core db-postgres monitoring ceph-node; do
    sudo incus profile delete "$profile" 2>/dev/null && log_info "Perfil eliminado: $profile" || true
  done

  log_warn "Eliminando volúmenes..."
  for volume in postgres-data prometheus-data grafana-data ceph-data app-data; do
    sudo incus storage volume delete default "$volume" 2>/dev/null && log_info "Volumen eliminado: $volume" || true
  done

  log_warn "Eliminando storage pool..."
  sudo incus storage delete default 2>/dev/null && log_info "Storage pool eliminado" || true

  log_error "Limpieza completa. Revisa los errores arriba y vuelve a ejecutar el script."
  exit 1
}

trap cleanup ERR

# -----------------------------------------------------------------------------
# PASO 0 — Verificaciones previas
# -----------------------------------------------------------------------------
log_section "PASO 0 — Verificaciones previas"

log_info "Verificando Incus..."
if ! sudo incus version &>/dev/null; then
  log_error "Incus no está instalado o no responde."
  exit 1
fi
INCUS_VERSION=$(sudo incus version | grep "Server version" | awk '{print $3}')
log_ok "Incus $INCUS_VERSION detectado"

log_info "Verificando OVN northd..."
if ! sudo /usr/share/ovn/scripts/ovn-ctl status_northd | grep -q "running"; then
  log_warn "OVN northd no está corriendo. Iniciando..."
  sudo /usr/share/ovn/scripts/ovn-ctl start_northd
fi
log_ok "OVN northd activo"

log_info "Verificando OVN controller..."
if ! sudo /usr/share/ovn/scripts/ovn-ctl status_controller | grep -q "running"; then
  log_warn "OVN controller no está corriendo. Iniciando..."
  sudo /usr/share/ovn/scripts/ovn-ctl start_controller
fi
log_ok "OVN controller activo"

log_info "Verificando Open vSwitch..."
if ! sudo systemctl is-active --quiet ovsdb-server; then
  log_error "ovsdb-server no está corriendo. Ejecuta: sudo systemctl start ovsdb-server"
  exit 1
fi
log_ok "Open vSwitch activo"

log_info "Configurando permisos del proyecto Incus..."
sudo incus project set default features.networks=true 2>/dev/null || true
log_ok "Permisos configurados"

# -----------------------------------------------------------------------------
# PASO 1 — Storage pool
# -----------------------------------------------------------------------------
log_section "PASO 1 — Storage pool"

if sudo incus storage show default &>/dev/null; then
  log_warn "Storage pool 'default' ya existe, omitiendo creación"
else
  sudo incus storage create default dir
  log_ok "Storage pool 'default' creado"
fi

# -----------------------------------------------------------------------------
# PASO 2 — Red bridge uplink
# -----------------------------------------------------------------------------
log_section "PASO 2 — Red bridge uplink (incusbr0)"

if sudo incus network show incusbr0 &>/dev/null; then
  log_warn "Bridge 'incusbr0' ya existe, omitiendo creación"
else
  sudo incus network create incusbr0 \
    --type=bridge \
    ipv4.address=10.10.0.1/24 \
    ipv4.nat=true
  log_ok "Bridge incusbr0 creado"
fi

log_info "Configurando rangos IP del bridge..."
sudo incus network set incusbr0 ipv4.address=10.10.0.1/24
sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=10.10.0.100-10.10.0.200 \
  ipv4.ovn.ranges=10.10.0.10-10.10.0.50
log_ok "Rangos configurados"

# -----------------------------------------------------------------------------
# PASO 3 — Red OVN
# -----------------------------------------------------------------------------
log_section "PASO 3 — Red OVN (lab-net)"

log_info "Configurando conexión Incus → OVN..."
sudo incus config set network.ovn.northbound_connection unix:/var/run/ovn/ovnnb_db.sock

if sudo incus network show lab-net &>/dev/null; then
  log_warn "Red 'lab-net' ya existe, omitiendo creación"
else
  sudo incus network create lab-net \
    --type=ovn \
    network=incusbr0 \
    ipv4.address=10.10.0.1/24 \
    ipv4.nat=true
  log_ok "Red OVN lab-net creada (10.10.0.0/24)"
fi

# -----------------------------------------------------------------------------
# PASO 4 — Perfiles de recursos
# -----------------------------------------------------------------------------
log_section "PASO 4 — Perfiles de recursos"

declare -A PROFILES
PROFILES=(
  ["node-control"]="cpu=1 memory=256MiB disk=4GiB"
  ["app-api"]="cpu=1 memory=768MiB disk=8GiB"
  ["app-core"]="cpu=1 memory=768MiB disk=8GiB"
  ["db-postgres"]="cpu=2 memory=2GiB disk=20GiB"
  ["monitoring"]="cpu=2 memory=1536MiB disk=10GiB"
  ["ceph-node"]="cpu=1 memory=512MiB disk=15GiB"
)

for profile in node-control app-api app-core db-postgres monitoring ceph-node; do
  config="${PROFILES[$profile]}"
  cpu=$(echo "$config" | grep -oP 'cpu=\K[^ ]+')
  memory=$(echo "$config" | grep -oP 'memory=\K[^ ]+')
  disk=$(echo "$config" | grep -oP 'disk=\K[^ ]+')

  if sudo incus profile show "$profile" &>/dev/null; then
    log_warn "Perfil '$profile' ya existe, actualizando límites..."
    sudo incus profile set "$profile" limits.cpu="$cpu" limits.memory="$memory"
  else
    sudo incus profile create "$profile"
    sudo incus profile set "$profile" limits.cpu="$cpu" limits.memory="$memory"
    log_ok "Perfil '$profile' creado (CPU: $cpu, RAM: $memory)"
  fi

  # CORRECCIÓN: Verificar y agregar disco root de forma explícita
  if ! sudo incus profile device show "$profile" 2>/dev/null | grep -q "^root:"; then
    sudo incus profile device add "$profile" root disk path=/ pool=default size="$disk"
    log_ok "Disco asignado a '$profile' ($disk)"
  else
    log_warn "Disco en '$profile' ya existe, omitiendo"
  fi
done

# -----------------------------------------------------------------------------
# PASO 5 — Volúmenes persistentes
# -----------------------------------------------------------------------------
log_section "PASO 5 — Volúmenes persistentes"

VOLUMES=("postgres-data" "prometheus-data" "grafana-data" "ceph-data" "app-data")

for volume in "${VOLUMES[@]}"; do
  if sudo incus storage volume show default "$volume" &>/dev/null; then
    log_warn "Volumen '$volume' ya existe, omitiendo"
  else
    sudo incus storage volume create default "$volume"
    log_ok "Volumen '$volume' creado"
  fi
done

# -----------------------------------------------------------------------------
# PASO 6 — Lanzar contenedores
# -----------------------------------------------------------------------------
log_section "PASO 6 — Lanzar contenedores Debian 13"

CONTAINERS=("node-control" "app-api" "app-core" "db-postgres" "monitoring" "ceph-node")

for container in "${CONTAINERS[@]}"; do
  if sudo incus info "$container" &>/dev/null; then
    log_warn "Contenedor '$container' ya existe"
    if ! sudo incus info "$container" | grep -q "Status: RUNNING"; then
      log_info "Iniciando '$container'..."
      sudo incus start "$container"
    else
      log_warn "'$container' ya está corriendo, omitiendo"
    fi
  else
    log_info "Lanzando '$container'..."
    sudo incus launch images:debian/13 "$container" -p "$container" --network lab-net
    log_ok "Contenedor '$container' lanzado"
  fi
done

# Esperar a que todos arranquen
log_info "Esperando 5 segundos para que los contenedores inicien..."
sleep 5

# -----------------------------------------------------------------------------
# PASO 7 — Verificación de conectividad
# -----------------------------------------------------------------------------
log_section "PASO 7 — Verificación de conectividad"

declare -A CONTAINER_IPS
log_info "Obteniendo IPs de los contenedores..."

for container in "${CONTAINERS[@]}"; do
  IP=$(sudo incus list "$container" --format csv -c 4 | grep -oP '[\d\.]+(?= \()' | head -1)
  if [ -z "$IP" ]; then
    log_warn "No se pudo obtener IP de '$container', esperando..."
    sleep 3
    IP=$(sudo incus list "$container" --format csv -c 4 | grep -oP '[\d\.]+(?= \()' | head -1)
  fi
  CONTAINER_IPS[$container]=$IP
  log_info "$container → $IP"
done

echo ""
log_info "Probando conectividad desde node-control..."
FAILED=0

for container in app-api app-core db-postgres monitoring ceph-node; do
  IP="${CONTAINER_IPS[$container]}"
  if [ -z "$IP" ]; then
    log_error "Sin IP para '$container', saltando ping"
    FAILED=$((FAILED + 1))
    continue
  fi

  if sudo incus exec node-control -- ping -c 2 -W 2 "$IP" &>/dev/null; then
    log_ok "node-control → $container ($IP) ✓"
  else
    log_error "node-control → $container ($IP) ✗ SIN RESPUESTA"
    FAILED=$((FAILED + 1))
  fi
done

# -----------------------------------------------------------------------------
# RESULTADO FINAL
# -----------------------------------------------------------------------------
log_section "RESULTADO FINAL"

echo ""
sudo incus list
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}"
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║   INFRAESTRUCTURA LEVANTADA           ║"
  echo "  ║   Todos los nodos responden ✓         ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo -e "${NC}"
  log_ok "Red OVN:    lab-net (10.10.0.0/24)"
  log_ok "Nodos:      6 contenedores Debian 13 RUNNING"
  log_ok "Storage:    pool default (dir)"
  log_ok "Volúmenes:  5 volúmenes persistentes"
  log_ok "Perfiles:   6 perfiles con límites de CPU, RAM y disco"
  echo ""
  log_info "Próximo paso → Etapa 2: OpenTofu + Ansible"
else
  echo -e "${YELLOW}"
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║   INFRAESTRUCTURA CON ADVERTENCIAS    ║"
  echo "  ║   $FAILED nodo(s) sin conectividad    ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo -e "${NC}"
  log_warn "Revisa los contenedores con: sudo incus list"
  log_warn "Revisa logs con: sudo incus log <nombre-contenedor>"
fi