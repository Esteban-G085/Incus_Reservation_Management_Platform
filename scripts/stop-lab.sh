#!/bin/bash
# =============================================================================
# stop-lab.sh — Apagado limpio del laboratorio Incus (CORREGIDO)
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
log_section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $1${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# -----------------------------------------------------------------------------
# PASO 1 — Detener contenedores en orden inverso de dependencias
# -----------------------------------------------------------------------------
log_section "PASO 1 — Deteniendo contenedores"

# Orden inverso: aplicación primero, infraestructura después
CONTAINERS_ORDER=("node-control" "app-api" "app-core" "monitoring" "db-postgres" "ceph-node")

for container in "${CONTAINERS_ORDER[@]}"; do
  if sudo incus info "$container" &>/dev/null; then
    if sudo incus info "$container" | grep -q "Status: RUNNING"; then
      log_info "Deteniendo '$container'..."
      sudo incus stop "$container" && log_ok "$container detenido"
    else
      log_warn "'$container' ya estaba detenido"
    fi
  else
    log_warn "'$container' no existe, omitiendo"
  fi
done

# -----------------------------------------------------------------------------
# PASO 2 — Detener OVN
# -----------------------------------------------------------------------------
log_section "PASO 2 — Deteniendo OVN"

log_info "Deteniendo OVN controller..."
sudo /usr/share/ovn/scripts/ovn-ctl stop_controller 2>/dev/null && log_ok "OVN controller detenido" || log_warn "OVN controller ya estaba detenido"

log_info "Deteniendo OVN northd..."
sudo /usr/share/ovn/scripts/ovn-ctl stop_northd 2>/dev/null && log_ok "OVN northd detenido" || log_warn "OVN northd ya estaba detenido"

# -----------------------------------------------------------------------------
# RESULTADO FINAL
# -----------------------------------------------------------------------------
log_section "ESTADO FINAL"

sudo incus list
echo ""
echo -e "${GREEN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   LABORATORIO APAGADO LIMPIAMENTE ✓   ║"
echo "  ║   Para volver: ./start-lab.sh         ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"