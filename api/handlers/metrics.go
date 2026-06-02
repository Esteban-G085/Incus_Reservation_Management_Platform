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
