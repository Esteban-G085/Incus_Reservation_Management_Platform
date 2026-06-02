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
	"reservas-api/storage"
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
		&models.Adjunto{},
	)

	if err := storage.InitCeph(); err != nil {
		log.Fatalf("Error inicializando Ceph: %v", err)
	}

	handlers.SetJWTSecret(cfg.JWTSecret)

	go func() {
		for {
			handlers.ActualizarMetricasNegocio()
			time.Sleep(30 * time.Second)
		}
	}()

	r := gin.Default()
	r.Use(middleware.Metrics())

	r.GET("/metrics", handlers.MetricsHandler())
	r.GET("/api/v1/health", handlers.Health)

	auth := r.Group("/api/v1/auth")
	{
		auth.POST("/register", handlers.Register)
		auth.POST("/login", handlers.Login)
	}

	r.GET("/api/v1/recursos", handlers.ListarRecursos)
	r.GET("/api/v1/recursos/:id", handlers.ObtenerRecurso)

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

		protected.POST("/reservas/:id/adjunto", handlers.SubirAdjunto)
		protected.GET("/reservas/:id/adjuntos", handlers.ListarAdjuntos)
	}

	r.GET("/api/v1/adjuntos/:id/descargar", handlers.DescargarAdjunto)
	r.DELETE("/api/v1/adjuntos/:id", middleware.AuthRequired(cfg.JWTSecret), handlers.EliminarAdjunto)

	log.Printf("Servidor iniciando en :%s", cfg.AppPort)
	if err := r.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("Error iniciando servidor: %v", err)
	}
}
