#!/bin/bash
# validate-services.sh
# Verifica el estado de todos los servicios instalados en los contenedores.
# Complementa validate.sh (que verifica infraestructura Incus).

REPO_DIR="$HOME/Incus_Reservation_Management_Platform"
PASS=0
FAIL=0

echo "=========================================="
echo "  VALIDACIÓN DE SERVICIOS"
echo "=========================================="
echo ""

# ─── Helpers ──────────────────────────────────────────────────────────────────
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

check_service() {
  local container=$1
  local service=$2
  local status
  status=$(incus exec "$container" -- systemctl is-active "$service" 2>/dev/null || echo "inactive")
  [ "$status" = "active" ] && ok "$container → $service" || fail "$container → $service ($status)"
}

check_port() {
  local container=$1
  local port=$2
  local label=$3
  if incus exec "$container" -- bash -c "ss -tlnp | grep -q ':$port'" 2>/dev/null; then
    ok "$container → $label escuchando en :$port"
  else
    fail "$container → $label no encontrado en :$port"
  fi
}

check_cmd() {
  local container=$1
  local cmd=$2
  local label=$3
  if incus exec "$container" -- bash -c "$cmd" &>/dev/null; then
    ok "$container → $label"
  else
    fail "$container → $label"
  fi
}

# ─── Ansible desde el host ────────────────────────────────────────────────────
echo "[1/7] Ansible y conectividad..."
if command -v ansible &>/dev/null; then
  ok "Ansible instalado ($(ansible --version | head -1 | awk '{print $3}'))"
else
  fail "Ansible no encontrado en el host"
fi

if [ -f "$REPO_DIR/inventory.ini" ]; then
  ok "inventory.ini existe"
  PING=$(cd "$REPO_DIR" && ansible all -i inventory.ini -m ping 2>/dev/null | grep -c "pong" || true)
  ok "Ansible ping: $PING/6 contenedores responden"
else
  fail "inventory.ini no encontrado"
fi
echo ""

# ─── Base (python3 + paquetes) ────────────────────────────────────────────────
echo "[2/7] Paquetes base en contenedores..."
for c in ctl api core db mon ceph; do
  check_cmd "$c" "python3 --version" "python3"
  check_cmd "$c" "curl --version" "curl"
done
echo ""

# ─── PostgreSQL ───────────────────────────────────────────────────────────────
echo "[3/7] PostgreSQL (db)..."
check_service db postgresql
check_port db 5432 "PostgreSQL"
check_cmd db "pg_isready" "pg_isready OK"
echo ""

# ─── Monitoring ───────────────────────────────────────────────────────────────
echo "[4/7] Prometheus + Grafana (mon)..."
check_service mon prometheus
check_service mon grafana-server
check_port mon 9090 "Prometheus"
check_port mon 3000 "Grafana"
echo ""

# ─── API Go ───────────────────────────────────────────────────────────────────
echo "[5/7] API Go + Gin (api)..."
check_service api reservas-api
check_cmd api "test -f /app/reservas-api/reservas-api" "binario compilado existe"
check_cmd api "test -d /app/reservas-api/handlers" "estructura Go existe"
check_port api 8080 "API Go"
check_cmd api "curl -s http://localhost:8080/api/v1/health | python3 -c \"import sys,json; d=json.load(sys.stdin); exit(0 if d.get('status')=='healthy' else 1)\"" "health endpoint responde"
check_cmd api "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/v1/adjuntos/999/descargar | grep -q 404" "adjuntos endpoint responde (404 esperado)"
echo ""

# ─── Frontend ─────────────────────────────────────────────────────────────────
echo "[6/7] Frontend React + Vite (core)..."
check_service core reservas-frontend
check_cmd core "test -d /app/frontend/dist" "build de produccion existe"
check_cmd core "test -f /app/frontend/package.json" "proyecto React existe"
check_port core 5173 "Vite dev server"
check_cmd core "curl -s -o /dev/null -w '%{http_code}' http://localhost:5173 | grep -q 200" "frontend responde HTTP 200"
echo ""

# ─── Ceph ─────────────────────────────────────────────────────────────────────
echo "[7/7] Ceph Storage (ceph)..."
check_cmd ceph "ceph -s --format json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('health','').get('status',''))\" | grep -q HEALTH_OK" "cluster HEALTH_OK"
check_cmd ceph "ceph osd pool ls 2>/dev/null | grep -q reservas-pool" "pool reservas-pool existe"
check_cmd ceph "ceph osd stat --format json 2>/dev/null | python3 -c \"import sys,json; print(json.load(sys.stdin).get('num_osds',0))\" | grep -q 1" "al menos 1 OSD"
check_cmd ceph "systemctl is-active ceph-mon@ceph1" "ceph-mon activo"
check_cmd ceph "systemctl is-active ceph-mgr@ceph1" "ceph-mgr activo"
check_cmd ceph "test -f /var/lib/ceph/osd.img" "loop device image existe"
check_cmd ceph "ceph auth get client.reservas 2>/dev/null | grep -q client.reservas" "client.reservas existe"
for c in api core; do
  check_cmd "$c" "ceph -s --name client.reservas 2>/dev/null | head -1" "cliente Ceph desde $c"
done
echo ""

# ─── Resumen ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS+FAIL))
echo "=========================================="
echo "  Resultados: $PASS/$TOTAL pasaron"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ Todos los servicios OK"
else
  echo "  ⚠️  $FAIL verificaciones fallaron — revisar arriba"
fi
echo "=========================================="
