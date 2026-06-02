package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"reservas-api/database"
)

func Health(c *gin.Context) {
	sqlDB, err := database.DB.DB()
	dbStatus := "ok"
	if err != nil || sqlDB.Ping() != nil {
		dbStatus = "error"
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "reservas-api",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"database":  dbStatus,
	})
}
