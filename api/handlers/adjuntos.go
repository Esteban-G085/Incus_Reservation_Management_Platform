package handlers

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"reservas-api/database"
	"reservas-api/models"
	"reservas-api/storage"
)

func SubirAdjunto(c *gin.Context) {
	reservaID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id de reserva inválido"})
		return
	}

	var reserva models.Reserva
	if err := database.DB.First(&reserva, reservaID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "reserva no encontrada"})
		return
	}

	file, header, err := c.Request.FormFile("archivo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "archivo no encontrado en la solicitud"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error leyendo archivo"})
		return
	}

	ext := filepath.Ext(header.Filename)
	oid := fmt.Sprintf("reserva_%d_%s%s", reservaID, time.Now().Format("20060102150405"), ext)

	if err := storage.UploadFile(oid, data); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error almacenando archivo en Ceph"})
		return
	}

	adjunto := models.Adjunto{
		ReservaID: uint(reservaID),
		Nombre:    header.Filename,
		MimeType:  header.Header.Get("Content-Type"),
		Tamanio:   int64(len(data)),
		CephOID:   oid,
	}

	if err := database.DB.Create(&adjunto).Error; err != nil {
		storage.DeleteFile(oid)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error guardando registro de adjunto"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": adjunto})
}

func ListarAdjuntos(c *gin.Context) {
	reservaID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id de reserva inválido"})
		return
	}

	var adjuntos []models.Adjunto
	database.DB.Where("reserva_id = ?", reservaID).Find(&adjuntos)
	c.JSON(http.StatusOK, gin.H{"data": adjuntos})
}

func DescargarAdjunto(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id de adjunto inválido"})
		return
	}

	var adjunto models.Adjunto
	if err := database.DB.First(&adjunto, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "adjunto no encontrado"})
		return
	}

	data, err := storage.DownloadFile(adjunto.CephOID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error descargando archivo de Ceph"})
		return
	}

	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, adjunto.Nombre))
	c.Header("Content-Type", adjunto.MimeType)
	c.Header("Content-Length", strconv.FormatInt(adjunto.Tamanio, 10))
	c.Data(http.StatusOK, adjunto.MimeType, data)
}

func EliminarAdjunto(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id de adjunto inválido"})
		return
	}

	var adjunto models.Adjunto
	if err := database.DB.First(&adjunto, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "adjunto no encontrado"})
		return
	}

	if err := storage.DeleteFile(adjunto.CephOID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error eliminando archivo de Ceph"})
		return
	}

	database.DB.Delete(&adjunto)
	c.JSON(http.StatusOK, gin.H{"message": "adjunto eliminado"})
}
