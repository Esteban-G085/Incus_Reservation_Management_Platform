package handlers

import (
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
    "reservas-api/database"
    "reservas-api/models"
)

var jwtSecret string

func SetJWTSecret(s string) { jwtSecret = s }

type LoginRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required"`
}

type RegisterRequest struct {
    Nombre   string `json:"nombre" binding:"required"`
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=6"`
}

func Register(c *gin.Context) {
    var req RegisterRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    usuario := models.Usuario{Nombre: req.Nombre, Email: req.Email}
    if err := usuario.SetPassword(req.Password); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "error procesando contraseña"})
        return
    }

    if err := database.DB.Create(&usuario).Error; err != nil {
        c.JSON(http.StatusConflict, gin.H{"error": "email ya registrado"})
        return
    }

    c.JSON(http.StatusCreated, gin.H{"data": usuario.ToResponse()})
}

func Login(c *gin.Context) {
    var req LoginRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    var usuario models.Usuario
    if err := database.DB.Where("email = ?", req.Email).First(&usuario).Error; err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "credenciales inválidas"})
        return
    }

    if !usuario.CheckPassword(req.Password) {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "credenciales inválidas"})
        return
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
        "sub": float64(usuario.IDUsuario),
        "exp": time.Now().Add(24 * time.Hour).Unix(),
    })

    tokenStr, err := token.SignedString([]byte(jwtSecret))
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "error generando token"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "token":   tokenStr,
        "usuario": usuario.ToResponse(),
    })
}
