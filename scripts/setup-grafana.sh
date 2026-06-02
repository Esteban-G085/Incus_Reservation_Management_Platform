#!/bin/bash
# setup-grafana.sh - Configura Grafana via API: datasource + dashboards

set -e

GRAFANA_URL="http://10.100.0.6:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
AUTH="$GRAFANA_USER:$GRAFANA_PASS"

echo "=========================================="
echo "  SETUP GRAFANA - Datasource + Dashboards"
echo "=========================================="
echo ""

# Esperar a que Grafana responda
echo "[0/4] Verificando Grafana..."
for i in $(seq 1 10); do
    if sudo incus exec mon -- curl -s "$GRAFANA_URL/api/health" | grep -q "ok"; then
        echo "  OK: Grafana responde"
        break
    fi
    echo "  Esperando... ($i/10)"
    sleep 3
done
echo ""

# ─── 1. Datasource Prometheus ────────────────────────────────────────────────
echo "[1/4] Configurando datasource Prometheus..."
sudo incus exec mon -- curl -s -X POST "$GRAFANA_URL/api/datasources" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://localhost:9090",
        "access": "proxy",
        "isDefault": true
    }' | grep -o '"message":"[^"]*"'
echo ""

# ─── 2. Dashboard: Sistema (Node Exporter) ───────────────────────────────────
echo "[2/4] Importando dashboard de sistema..."
sudo incus exec mon -- curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -d '{
  "dashboard": {
    "title": "Sistema - Contenedores Lab",
    "tags": ["lab", "sistema"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage %",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[2m])) * 100)",
          "legendFormat": "{{instance}}"
        }],
        "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100}}
      },
      {
        "id": 2,
        "title": "RAM Usada %",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",
          "legendFormat": "{{instance}}"
        }],
        "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100}}
      },
      {
        "id": 3,
        "title": "RAM Disponible",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "node_memory_MemAvailable_bytes{instance=\"api:9100\"}",
          "legendFormat": "api"
        }],
        "fieldConfig": {"defaults": {"unit": "bytes"}}
      },
      {
        "id": 4,
        "title": "RAM Disponible DB",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "node_memory_MemAvailable_bytes{instance=\"db:9100\"}",
          "legendFormat": "db"
        }],
        "fieldConfig": {"defaults": {"unit": "bytes"}}
      },
      {
        "id": 5,
        "title": "Disco Usado %",
        "type": "gauge",
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "(1 - node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"}) * 100",
          "legendFormat": "{{instance}}"
        }],
        "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100}}
      },
      {
        "id": 6,
        "title": "Network I/O",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12},
        "targets": [
          {
            "datasource": "Prometheus",
            "expr": "rate(node_network_receive_bytes_total{device!=\"lo\"}[2m])",
            "legendFormat": "RX {{instance}} {{device}}"
          },
          {
            "datasource": "Prometheus",
            "expr": "rate(node_network_transmit_bytes_total{device!=\"lo\"}[2m])",
            "legendFormat": "TX {{instance}} {{device}}"
          }
        ],
        "fieldConfig": {"defaults": {"unit": "binBps"}}
      }
    ],
    "refresh": "30s",
    "schemaVersion": 38,
    "version": 1
  },
  "overwrite": true,
  "folderId": 0
}' | grep -o '"status":"[^"]*"'
echo ""

# ─── 3. Dashboard: API Reservas ───────────────────────────────────────────────
echo "[3/4] Importando dashboard de la API..."
sudo incus exec mon -- curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -d '{
  "dashboard": {
    "title": "API Reservas - Métricas",
    "tags": ["lab", "api", "go"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Requests por segundo",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "rate(http_requests_total[2m])",
          "legendFormat": "{{method}} {{path}} {{status}}"
        }],
        "fieldConfig": {"defaults": {"unit": "reqps"}}
      },
      {
        "id": 2,
        "title": "Latencia P95 (ms)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[2m])) * 1000",
          "legendFormat": "P95 {{path}}"
        }],
        "fieldConfig": {"defaults": {"unit": "ms"}}
      },
      {
        "id": 3,
        "title": "Requests en vuelo",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 0, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "http_requests_in_flight",
          "legendFormat": "En vuelo"
        }],
        "fieldConfig": {"defaults": {"unit": "short"}}
      },
      {
        "id": 4,
        "title": "Reservas Activas",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 4, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "reservas_activas_total",
          "legendFormat": "Reservas"
        }],
        "fieldConfig": {"defaults": {"unit": "short", "color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": 0}]}}}
      },
      {
        "id": 5,
        "title": "Usuarios Registrados",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 8, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "usuarios_registrados_total",
          "legendFormat": "Usuarios"
        }],
        "fieldConfig": {"defaults": {"unit": "short", "color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "blue", "value": 0}]}}}
      },
      {
        "id": 6,
        "title": "Recursos Disponibles",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 12, "y": 8},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "recursos_disponibles_total",
          "legendFormat": "Recursos"
        }],
        "fieldConfig": {"defaults": {"unit": "short", "color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "yellow", "value": 0}]}}}
      },
      {
        "id": 7,
        "title": "Tasa de errores (4xx + 5xx)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "rate(http_requests_total{status=~\"4..|5..\"}[2m])",
          "legendFormat": "{{status}} {{path}}"
        }],
        "fieldConfig": {"defaults": {"unit": "reqps", "color": {"fixedColor": "red", "mode": "fixed"}}}
      },
      {
        "id": 8,
        "title": "Goroutines Go",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
        "targets": [{
          "datasource": "Prometheus",
          "expr": "go_goroutines",
          "legendFormat": "Goroutines"
        }],
        "fieldConfig": {"defaults": {"unit": "short"}}
      },
      {
        "id": 9,
        "title": "Latencia P50 / P95 / P99",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20},
        "targets": [
          {
            "datasource": "Prometheus",
            "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[2m])) * 1000",
            "legendFormat": "P50"
          },
          {
            "datasource": "Prometheus",
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[2m])) * 1000",
            "legendFormat": "P95"
          },
          {
            "datasource": "Prometheus",
            "expr": "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[2m])) * 1000",
            "legendFormat": "P99"
          }
        ],
        "fieldConfig": {"defaults": {"unit": "ms"}}
      }
    ],
    "refresh": "15s",
    "schemaVersion": 38,
    "version": 1
  },
  "overwrite": true,
  "folderId": 0
}' | grep -o '"status":"[^"]*"'
echo ""

# ─── 4. Verificación ─────────────────────────────────────────────────────────
echo "[4/4] Verificando dashboards..."
DASH_COUNT=$(sudo incus exec mon -- curl -s "$GRAFANA_URL/api/search" \
    -u "$AUTH" | grep -o '"title"' | wc -l)
echo "  Dashboards registrados: $DASH_COUNT"
echo ""

echo "=========================================="
echo "  ✅ GRAFANA CONFIGURADO"
echo "=========================================="
echo ""
echo "  Accede a Grafana:"
echo "    sudo incus exec mon -- curl -s http://localhost:3000/api/dashboards/home"
echo ""
echo "  O lista los dashboards:"
echo "    sudo incus exec mon -- curl -s -u admin:admin http://localhost:3000/api/search | python3 -m json.tool"
echo ""
echo "  Siguiente paso: sudo bash scripts/setup-frontend.sh"
echo ""
