#!/bin/bash
# start-services.sh
# Arranca o reinicia los servicios dentro de los contenedores.
# Útil después de un reinicio del host o de los contenedores.
# Prerequisito: los contenedores deben estar RUNNING (usa startup.sh primero si no lo están).

set -e

echo "=========================================="
echo "  ARRANQUE DE SERVICIOS"
echo "=========================================="
echo ""

start_service() {
  local container=$1
  local service=$2
  local status
  status=$(incus exec "$container" -- systemctl is-active "$service" 2>/dev/null || echo "inactive")
  if [ "$status" = "active" ]; then
    echo "  ✅ $container → $service ya estaba activo"
  else
    echo "  🔄 $container → $service: arrancando..."
    incus exec "$container" -- systemctl start "$service"
    sleep 2
    status=$(incus exec "$container" -- systemctl is-active "$service" 2>/dev/null || echo "inactive")
    if [ "$status" = "active" ]; then
      echo "  ✅ $container → $service: activo"
    else
      echo "  ❌ $container → $service: falló ($status)"
    fi
  fi
}

# ─── Verificar que los contenedores están corriendo ───────────────────────────
echo "[1/4] Verificando contenedores..."
for c in ctl api core db mon ceph; do
  state=$(incus list "$c" --format csv --columns s 2>/dev/null | head -1)
  if [ "$state" = "RUNNING" ]; then
    echo "  ✅ $c: RUNNING"
  else
    echo "  ❌ $c: $state — ejecuta startup.sh primero"
    exit 1
  fi
done
echo ""

# ─── PostgreSQL ───────────────────────────────────────────────────────────────
echo "[2/4] PostgreSQL (db)..."
start_service db postgresql
echo ""

# ─── Monitoring ───────────────────────────────────────────────────────────────
echo "[3/4] Prometheus + Grafana (mon)..."
start_service mon prometheus
start_service mon grafana-server
echo ""

# ─── App ──────────────────────────────────────────────────────────────────────
echo "[4/4] FastAPI (api + core)..."
for c in api core; do
  if incus exec "$c" -- systemctl list-units --type=service | grep -q "app.service"; then
    start_service "$c" app
  else
    echo "  ⚠️  $c → app.service aún no configurado (pendiente)"
  fi
done
echo ""

echo "=========================================="
echo "  ✅ ARRANQUE DE SERVICIOS COMPLETADO"
echo "=========================================="
echo ""
echo "  Accesos:"
echo "    Grafana:    http://$(incus list mon --format csv --columns 4 | cut -d' ' -f1):3000  (admin/admin)"
echo "    Prometheus: http://$(incus list mon --format csv --columns 4 | cut -d' ' -f1):9090"
echo "    PostgreSQL: $(incus list db --format csv --columns 4 | cut -d' ' -f1):5432"
echo ""
