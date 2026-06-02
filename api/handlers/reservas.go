package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "reservas-api/database"
    "reservas-api/models"
)

func ListarReservas(c *gin.Context) {
    userID, _ := c.Get("user_id")
    var reservas []models.Reserva
    database.DB.Where("id_usuario = ?", userID).Find(&reservas)
    c.JSON(http.StatusOK, gin.H{"data": reservas})
}

func CrearReserva(c *gin.Context) {
    userID, _ := c.Get("user_id")
    var reserva models.Reserva
    if err := c.ShouldBindJSON(&reserva); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    reserva.IDUsuario = userID.(uint)

    // Verificar que el recurso esté disponible
    var recurso models.Recurso
    if err := database.DB.First(&recurso, reserva.IDRecurso).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "recurso no encontrado"})
        return
    }
    if recurso.Estado != "disponible" {
        c.JSON(http.StatusConflict, gin.H{"error": "recurso no disponible"})
        return
    }

    // Verificar solapamiento de fechas
    var count int64
    database.DB.Model(&models.Reserva{}).
        Where("id_recurso = ? AND estado_reserva = 'confirmada' AND fecha_inicio < ? AND fecha_fin > ?",
            reserva.IDRecurso, reserva.FechaFin, reserva.FechaInicio).
        Count(&count)
    if count > 0 {
        c.JSON(http.StatusConflict, gin.H{"error": "el recurso ya tiene una reserva en ese horario"})
        return
    }

    database.DB.Create(&reserva)
    c.JSON(http.StatusCreated, gin.H{"data": reserva})
}

func ObtenerReserva(c *gin.Context) {
    userID, _ := c.Get("user_id")
    var reserva models.Reserva
    if err := database.DB.Where("id_reserva = ? AND id_usuario = ?", c.Param("id"), userID).
        First(&reserva).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "reserva no encontrada"})
        return
    }
    c.JSON(http.StatusOK, gin.H{"data": reserva})
}

func CancelarReserva(c *gin.Context) {
    userID, _ := c.Get("user_id")
    var reserva models.Reserva
    if err := database.DB.Where("id_reserva = ? AND id_usuario = ?", c.Param("id"), userID).
        First(&reserva).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "reserva no encontrada"})
        return
    }
    database.DB.Model(&reserva).Update("estado_reserva", "cancelada")
    c.JSON(http.StatusOK, gin.H{"message": "reserva cancelada"})
}
