#!/bin/bash
# =============================================================================
# start-lab.sh — Arranque del laboratorio Incus (CORREGIDO)
# Proyecto: Plataforma de Gestión de Reservas
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Colores
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $1${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# -----------------------------------------------------------------------------
# PASO 0 — Verificar dependencias
# -----------------------------------------------------------------------------
log_section "PASO 0 — Verificando dependencias"

log_info "Verificando Open vSwitch..."
if ! sudo systemctl is-active --quiet ovsdb-server; then
  log_warn "ovsdb-server no está corriendo. Iniciando..."
  sudo systemctl start ovsdb-server
fi
if ! sudo systemctl is-active --quiet ovs-vswitchd; then
  log_warn "ovs-vswitchd no está corriendo. Iniciando..."
  sudo systemctl start ovs-vswitchd
fi
log_ok "Open vSwitch activo"

# -----------------------------------------------------------------------------
# PASO 1 — Iniciar OVN
# -----------------------------------------------------------------------------
log_section "PASO 1 — Iniciando OVN"

log_info "Verificando OVN northd..."
if sudo /usr/share/ovn/scripts/ovn-ctl status_northd 2>/dev/null | grep -q "running"; then
  log_warn "OVN northd ya estaba corriendo"
else
  sudo /usr/share/ovn/scripts/ovn-ctl start_northd
  log_ok "OVN northd iniciado"
fi

log_info "Verificando OVN controller..."
if sudo /usr/share/ovn/scripts/ovn-ctl status_controller 2>/dev/null | grep -q "running"; then
  log_warn "OVN controller ya estaba corriendo"
else
  sudo /usr/share/ovn/scripts/ovn-ctl start_controller
  log_ok "OVN controller iniciado"
fi

# -----------------------------------------------------------------------------
# PASO 2 — Iniciar contenedores en orden de dependencias
# -----------------------------------------------------------------------------
log_section "PASO 2 — Iniciando contenedores"

# Orden: infraestructura primero, aplicación después
CONTAINERS_ORDER=("ceph-node" "db-postgres" "monitoring" "app-core" "app-api" "node-control")

for container in "${CONTAINERS_ORDER[@]}"; do
  if sudo incus info "$container" &>/dev/null; then
    if sudo incus info "$container" | grep -q "Status: RUNNING"; then
      log_warn "'$container' ya estaba corriendo"
    else
      log_info "Iniciando '$container'..."
      sudo incus start "$container" && log_ok "$container iniciado"
    fi
  else
    log_error "'$container' no existe. Ejecuta setup-lab.sh primero."
  fi
done

log_info "Esperando 5 segundos para que los contenedores obtengan IP..."
sleep 5

# -----------------------------------------------------------------------------
# PASO 3 — Verificar conectividad
# -----------------------------------------------------------------------------
log_section "PASO 3 — Verificando conectividad"

FAILED=0
for container in app-api app-core db-postgres monitoring ceph-node; do
  IP=$(sudo incus list "$container" --format csv -c 4 | grep -oP '[\d\.]+(?= \()' | head -1)
  if [ -z "$IP" ]; then
    log_error "Sin IP para '$container'"
    FAILED=$((FAILED + 1))
    continue
  fi

  if sudo incus exec node-control -- ping -c 2 -W 2 "$IP" &>/dev/null; then
    log_ok "node-control → $container ($IP) ✓"
  else
    log_error "node-control → $container ($IP) ✗"
    FAILED=$((FAILED + 1))
  fi
done

# -----------------------------------------------------------------------------
# RESULTADO FINAL
# -----------------------------------------------------------------------------
log_section "ESTADO FINAL"

sudo incus list
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}"
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║   LABORATORIO LISTO ✓                 ║"
  echo "  ║   Todos los nodos responden           ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo -e "${NC}"
else
  echo -e "${YELLOW}"
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║   LABORATORIO CON ADVERTENCIAS        ║"
  echo "  ║   $FAILED nodo(s) sin respuesta       ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo -e "${NC}"
  log_warn "Revisa con: sudo incus list"
fi