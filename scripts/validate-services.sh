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
echo "[1/5] Ansible y conectividad..."
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
echo "[2/5] Paquetes base en contenedores..."
for c in ctl api core db mon ceph; do
  check_cmd "$c" "python3 --version" "python3"
  check_cmd "$c" "curl --version" "curl"
done
echo ""

# ─── PostgreSQL ───────────────────────────────────────────────────────────────
echo "[3/5] PostgreSQL (db)..."
check_service db postgresql
check_port db 5432 "PostgreSQL"
check_cmd db "pg_isready" "pg_isready OK"
echo ""

# ─── Monitoring ───────────────────────────────────────────────────────────────
echo "[4/5] Prometheus + Grafana (mon)..."
check_service mon prometheus
check_service mon grafana-server
check_port mon 9090 "Prometheus"
check_port mon 3000 "Grafana"
echo ""

# ─── App ──────────────────────────────────────────────────────────────────────
echo "[5/5] FastAPI (api + core)..."
for c in api core; do
  check_cmd "$c" "[ -d /app/venv ]" "venv existe"
  check_cmd "$c" "/app/venv/bin/python -c 'import fastapi'" "FastAPI importable"
  check_cmd "$c" "/app/venv/bin/python -c 'import uvicorn'" "uvicorn importable"
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
