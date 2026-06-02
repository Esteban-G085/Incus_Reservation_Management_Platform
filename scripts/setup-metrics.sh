#!/bin/bash
# setup-metrics.sh - Agrega métricas Prometheus al API Go y configura scraping

set -e

echo "=========================================="
echo "  SETUP MÉTRICAS - Prometheus + Go API"
echo "=========================================="
echo ""

# ─── 1. Agregar métricas al API Go ────────────────────────────────────────────
echo "[1/4] Agregando métricas Prometheus al API Go..."
sudo incus exec api -- bash <<'API_METRICS'

set -e
export PATH=$PATH:/usr/local/go/bin
cd /app/reservas-api

# Agregar dependencia
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promauto
go get github.com/prometheus/client_golang/prometheus/promhttp

# Crear middleware de métricas
cat > middleware/metrics.go <<'METRICS_MW'
package middleware

import (
    "strconv"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "http_requests_total",
        Help: "Total de requests HTTP por método, ruta y status",
    }, []string{"method", "path", "status"})

    httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "http_request_duration_seconds",
        Help:    "Duración de requests HTTP en segundos",
        Buckets: prometheus.DefBuckets,
    }, []string{"method", "path"})

    httpRequestsInFlight = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "http_requests_in_flight",
        Help: "Requests HTTP actualmente en procesamiento",
    })
)

func Metrics() gin.HandlerFunc {
    return func(c *gin.Context) {
        if c.FullPath() == "/metrics" {
            c.Next()
            return
        }

        start := time.Now()
        httpRequestsInFlight.Inc()

        c.Next()

        httpRequestsInFlight.Dec()
        duration := time.Since(start).Seconds()
        status := strconv.Itoa(c.Writer.Status())
        path := c.FullPath()
        if path == "" {
            path = "unknown"
        }

        httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
        httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
    }
}
METRICS_MW

# Crear handler de métricas de negocio
cat > handlers/metrics.go <<'METRICS_HANDLER'
package handlers

import (
    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "reservas-api/database"
    "reservas-api/models"
)

var (
    reservasActivas = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "reservas_activas_total",
        Help: "Total de reservas con estado confirmada",
    })

    usuariosRegistrados = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "usuarios_registrados_total",
        Help: "Total de usuarios registrados",
    })

    recursosDisponibles = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "recursos_disponibles_total",
        Help: "Total de recursos con estado disponible",
    })
)

func MetricsHandler() gin.HandlerFunc {
    return gin.WrapH(promhttp.Handler())
}

func ActualizarMetricasNegocio() {
    var reservas, usuarios, recursos int64
    database.DB.Model(&models.Reserva{}).Where("estado_reserva = ?", "confirmada").Count(&reservas)
    database.DB.Model(&models.Usuario{}).Count(&usuarios)
    database.DB.Model(&models.Recurso{}).Where("estado = ?", "disponible").Count(&recursos)

    reservasActivas.Set(float64(reservas))
    usuariosRegistrados.Set(float64(usuarios))
    recursosDisponibles.Set(float64(recursos))
}
METRICS_HANDLER

# Actualizar main.go para incluir métricas
cat > main.go <<'MAIN'
package main

import (
    "log"
    "time"

    "github.com/gin-gonic/gin"
    "reservas-api/config"
    "reservas-api/database"
    "reservas-api/handlers"
    "reservas-api/middleware"
    "reservas-api/models"
)

func main() {
    cfg := config.Load()

    if cfg.AppEnv == "production" {
        gin.SetMode(gin.ReleaseMode)
    }

    database.Connect(cfg.DatabaseURL)
    database.Migrate(
        &models.Usuario{},
        &models.Recurso{},
        &models.Reserva{},
    )

    handlers.SetJWTSecret(cfg.JWTSecret)

    // Actualizar métricas de negocio cada 30 segundos
    go func() {
        for {
            handlers.ActualizarMetricasNegocio()
            time.Sleep(30 * time.Second)
        }
    }()

    r := gin.Default()
    r.Use(middleware.Metrics())

    // Métricas (público para Prometheus)
    r.GET("/metrics", handlers.MetricsHandler())

    // Health check
    r.GET("/api/v1/health", handlers.Health)

    // Auth (público)
    auth := r.Group("/api/v1/auth")
    {
        auth.POST("/register", handlers.Register)
        auth.POST("/login", handlers.Login)
    }

    // Recursos (público para consulta)
    r.GET("/api/v1/recursos", handlers.ListarRecursos)
    r.GET("/api/v1/recursos/:id", handlers.ObtenerRecurso)

    // Rutas protegidas con JWT
    protected := r.Group("/api/v1")
    protected.Use(middleware.AuthRequired(cfg.JWTSecret))
    {
        protected.POST("/recursos", handlers.CrearRecurso)
        protected.PUT("/recursos/:id", handlers.ActualizarRecurso)
        protected.DELETE("/recursos/:id", handlers.EliminarRecurso)

        protected.GET("/reservas", handlers.ListarReservas)
        protected.POST("/reservas", handlers.CrearReserva)
        protected.GET("/reservas/:id", handlers.ObtenerReserva)
        protected.DELETE("/reservas/:id", handlers.CancelarReserva)
    }

    log.Printf("Servidor iniciando en :%s", cfg.AppPort)
    if err := r.Run(":" + cfg.AppPort); err != nil {
        log.Fatalf("Error iniciando servidor: %v", err)
    }
}
MAIN

# Recompilar
go mod tidy
go build -o reservas-api .
systemctl restart reservas-api
sleep 2
echo "  Status API: $(systemctl is-active reservas-api)"

# Verificar endpoint de métricas
if curl -s http://localhost:8080/metrics | grep -q "http_requests_total"; then
    echo "  OK: /metrics respondiendo"
else
    echo "  WARN: /metrics no responde aún"
fi

API_METRICS
echo ""

# ─── 2. Configurar Prometheus para scrapear la API ───────────────────────────
echo "[2/4] Configurando Prometheus..."
sudo incus exec mon -- bash <<'PROM_CONFIG'

set -e

# Obtener IP del contenedor api
API_IP=$(getent hosts api | awk '{print $1}' | head -1)
echo "  IP de api: $API_IP"

cat > /etc/prometheus/prometheus.yml <<PROMYML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'reservas-api'
    static_configs:
      - targets: ['api:8080']
    metrics_path: '/metrics'

  - job_name: 'node-api'
    static_configs:
      - targets: ['api:9100']

  - job_name: 'node-db'
    static_configs:
      - targets: ['db:9100']

  - job_name: 'node-core'
    static_configs:
      - targets: ['core:9100']
PROMYML

systemctl restart prometheus
sleep 2
echo "  Status Prometheus: $(systemctl is-active prometheus)"

PROM_CONFIG
echo ""

# ─── 3. Instalar node_exporter en contenedores clave ─────────────────────────
echo "[3/4] Instalando node_exporter en api, db y core..."
for CONTAINER in api db core; do
    echo "  → $CONTAINER"
    sudo incus exec $CONTAINER -- bash <<NODE_EXP
apt install -y prometheus-node-exporter -qq > /dev/null 2>&1
systemctl enable prometheus-node-exporter > /dev/null 2>&1
systemctl start prometheus-node-exporter > /dev/null 2>&1
echo "    Status node_exporter: \$(systemctl is-active prometheus-node-exporter)"
NODE_EXP
done
echo ""

# ─── 4. Verificación final ───────────────────────────────────────────────────
echo "[4/4] Verificación final..."
sleep 3

echo ""
API_METRICS_OK=$(sudo incus exec api -- curl -s http://localhost:8080/metrics | grep -c "http_requests_total" || echo 0)
PROM_OK=$(sudo incus exec mon -- systemctl is-active prometheus)
GRAFANA_OK=$(sudo incus exec mon -- systemctl is-active grafana-server)

[ "$API_METRICS_OK" -gt 0 ] && echo "  ✅ API /metrics: ok" || echo "  ❌ API /metrics: no responde"
[ "$PROM_OK" = "active" ] && echo "  ✅ Prometheus: activo" || echo "  ❌ Prometheus: $PROM_OK"
[ "$GRAFANA_OK" = "active" ] && echo "  ✅ Grafana: activo" || echo "  ❌ Grafana: $GRAFANA_OK"

echo ""
echo "=========================================="
echo "  ✅ MÉTRICAS CONFIGURADAS"
echo "=========================================="
echo ""
echo "  Prometheus: http://10.100.0.6:9090"
echo "  Grafana:    http://10.100.0.6:3000  (admin/admin)"
echo ""
echo "  Targets Prometheus:"
echo "    - reservas-api  → api:8080/metrics"
echo "    - node-api       → api:9100"
echo "    - node-db        → db:9100"
echo "    - node-core      → core:9100"
echo ""
echo "  Siguiente paso: sudo bash scripts/setup-grafana.sh"
echo ""
