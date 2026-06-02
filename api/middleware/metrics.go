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
