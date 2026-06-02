package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "reservas-api/database"
    "reservas-api/models"
)

func ListarRecursos(c *gin.Context) {
    var recursos []models.Recurso
    database.DB.Find(&recursos)
    c.JSON(http.StatusOK, gin.H{"data": recursos})
}

func CrearRecurso(c *gin.Context) {
    var recurso models.Recurso
    if err := c.ShouldBindJSON(&recurso); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    database.DB.Create(&recurso)
    c.JSON(http.StatusCreated, gin.H{"data": recurso})
}

func ObtenerRecurso(c *gin.Context) {
    var recurso models.Recurso
    if err := database.DB.First(&recurso, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "recurso no encontrado"})
        return
    }
    c.JSON(http.StatusOK, gin.H{"data": recurso})
}

func ActualizarRecurso(c *gin.Context) {
    var recurso models.Recurso
    if err := database.DB.First(&recurso, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "recurso no encontrado"})
        return
    }
    if err := c.ShouldBindJSON(&recurso); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    database.DB.Save(&recurso)
    c.JSON(http.StatusOK, gin.H{"data": recurso})
}

func EliminarRecurso(c *gin.Context) {
    if err := database.DB.Delete(&models.Recurso{}, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "recurso no encontrado"})
        return
    }
    c.JSON(http.StatusOK, gin.H{"message": "recurso eliminado"})
}
