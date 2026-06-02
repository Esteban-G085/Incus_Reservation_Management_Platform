#!/bin/bash
# setup-api-go.sh - Reemplaza Flask/FastAPI por una API REST en Go + Gin

set -e

echo "=========================================="
echo "  SETUP API REST - Go + Gin (app-api)"
echo "=========================================="
echo ""

sudo incus exec api -- bash <<'API_GO'

set -e

# ─── 1. Limpiar Python/FastAPI anterior ───────────────────────────────────────
echo "[1/9] Limpiando entorno Python anterior..."
systemctl stop reservas-api 2>/dev/null || true
systemctl disable reservas-api 2>/dev/null || true
rm -f /etc/systemd/system/reservas-api.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /app/reservas-api
echo "  OK: entorno anterior eliminado"
echo "  OK: entorno anterior eliminado"

# ????????? 1b. Copiar fuente Go desde el repositorio (si existe) ????????????????????????????????????????????????????????????
if [ -d /root/Incus_Reservation_Management_Platform/api ]; then
    echo "[1b/9] Copiando codigo fuente Go desde el repositorio..."
    mkdir -p /app/reservas-api
    cp -r /root/Incus_Reservation_Management_Platform/api/* /app/reservas-api/
    rm -f /app/reservas-api/.env.example
    echo "  OK: codigo copiado desde repositorio"
else
    echo "[1b/9] Repositorio no encontrado, creando archivos desde cero..."
fi


# ─── 2. Instalar Go ───────────────────────────────────────────────────────────
echo "[2/9] Instalando Go..."
GO_VERSION="1.22.3"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"

if ! command -v go &>/dev/null; then
    apt install -y wget > /dev/null 2>&1
    wget -q "https://go.dev/dl/${GO_TAR}" -O "/tmp/${GO_TAR}"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "/tmp/${GO_TAR}"
    rm "/tmp/${GO_TAR}"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
    echo 'export GOPATH=/root/go' >> /etc/profile.d/go.sh
    echo 'export PATH=$PATH:$GOPATH/bin' >> /etc/profile.d/go.sh
fi

export PATH=$PATH:/usr/local/go/bin
export GOPATH=/root/go
go version
echo "  OK: Go instalado"

# ─── 3. Crear estructura del proyecto ─────────────────────────────────────────
echo "[3/9] Creando estructura del proyecto..."
mkdir -p /app/reservas-api/{handlers,models,middleware,database,config}
cd /app/reservas-api
echo "  OK: directorios creados"

# ─── 4. go.mod y dependencias ─────────────────────────────────────────────────
echo "[4/9] Inicializando módulo Go e instalando dependencias..."
export PATH=$PATH:/usr/local/go/bin

cat > go.mod <<'GOMOD'
module reservas-api

go 1.22

require (
    github.com/gin-gonic/gin v1.12.0
    github.com/golang-jwt/jwt/v5 v5.3.1
    github.com/joho/godotenv v1.5.1
    github.com/prometheus/client_golang v1.23.2
    golang.org/x/crypto v0.52.0
    gorm.io/driver/postgres v1.6.0
    gorm.io/gorm v1.31.1
)
GOMOD

go mod tidy
echo "  OK: dependencias instaladas"

# ─── 5. .env ──────────────────────────────────────────────────────────────────
echo "[5/9] Creando .env..."
cat > .env <<'ENV'
APP_ENV=development
APP_PORT=8080
DATABASE_URL=postgres://reservas_user:SecurePassword123!@db:5432/reservas_db?sslmode=disable
JWT_SECRET=reservas-jwt-secret-key-2026
JWT_EXPIRY_HOURS=24
ENV
echo "  OK: .env creado"

# ─── 6. Código fuente ─────────────────────────────────────────────────────────
echo "[6/9] Escribiendo código fuente..."

# config/config.go
cat > config/config.go <<'CONFIG'
package config

import (
    "log"
    "os"
    "strconv"

    "github.com/joho/godotenv"
)

type Config struct {
    AppEnv      string
    AppPort     string
    DatabaseURL string
    JWTSecret   string
    JWTExpiry   int
}

func Load() *Config {
    if err := godotenv.Load(); err != nil {
        log.Println("Advertencia: no se encontró .env, usando variables de entorno del sistema")
    }

    expiry, _ := strconv.Atoi(getEnv("JWT_EXPIRY_HOURS", "24"))

    return &Config{
        AppEnv:      getEnv("APP_ENV", "development"),
        AppPort:     getEnv("APP_PORT", "8080"),
        DatabaseURL: getEnv("DATABASE_URL", ""),
        JWTSecret:   getEnv("JWT_SECRET", "secret"),
        JWTExpiry:   expiry,
    }
}

func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}
CONFIG

# database/db.go
cat > database/db.go <<'DATABASE'
package database

import (
    "log"

    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

var DB *gorm.DB

func Connect(dsn string) {
    var err error
    for i := 0; i < 30; i++ {
        DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
            Logger: logger.Default.LogMode(logger.Silent),
            DisableForeignKeyConstraintWhenMigrating: true,
        })
        if err == nil {
            log.Println("Conexión a PostgreSQL establecida")
            return
        }
        log.Printf("Esperando PostgreSQL (intento %d/30): %v", i+1, err)
        time.Sleep(2 * time.Second)
    }
    log.Fatalf("No se pudo conectar a PostgreSQL tras 30 intentos: %v", err)
}

func Migrate(models ...interface{}) {
    if err := DB.AutoMigrate(models...); err != nil {
        log.Fatalf("Error en migración: %v", err)
    }
    log.Println("Migraciones completadas")
}
DATABASE

# models/usuario.go
cat > models/usuario.go <<'MODEL_USER'
package models

import (
    "time"

    "golang.org/x/crypto/bcrypt"
    "gorm.io/gorm"
)

type Usuario struct {
    IDUsuario    uint           `gorm:"primaryKey;column:id_usuario" json:"id_usuario"`
    Nombre       string         `gorm:"size:100;not null" json:"nombre"`
    Email        string         `gorm:"size:100;uniqueIndex;not null" json:"email"`
    PasswordHash string         `gorm:"type:text;not null" json:"-"`
    CreatedAt    time.Time      `json:"created_at"`
    UpdatedAt    time.Time      `json:"updated_at"`
    DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (u *Usuario) SetPassword(password string) error {
    hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return err
    }
    u.PasswordHash = string(hash)
    return nil
}

func (u *Usuario) CheckPassword(password string) bool {
    return bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)) == nil
}

func (u *Usuario) ToResponse() map[string]interface{} {
    return map[string]interface{}{
        "id_usuario": u.IDUsuario,
        "nombre":     u.Nombre,
        "email":      u.Email,
        "created_at": u.CreatedAt,
    }
}
MODEL_USER

# models/recurso.go
cat > models/recurso.go <<'MODEL_RECURSO'
package models

import (
    "time"

    "gorm.io/gorm"
)

type Recurso struct {
    IDRecurso uint           `gorm:"primaryKey;column:id_recurso" json:"id_recurso"`
    Nombre    string         `gorm:"size:100;not null" json:"nombre"`
    Tipo      string         `gorm:"size:50;not null" json:"tipo"`
    Estado    string         `gorm:"size:20;default:disponible;not null" json:"estado"`
    CreatedAt time.Time      `json:"created_at"`
    UpdatedAt time.Time      `json:"updated_at"`
    DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
MODEL_RECURSO

# models/reserva.go
cat > models/reserva.go <<'MODEL_RESERVA'
package models

import (
    "time"

    "gorm.io/gorm"
)

type Reserva struct {
    IDReserva    uint           `gorm:"primaryKey;column:id_reserva" json:"id_reserva"`
    IDUsuario    uint           `gorm:"not null" json:"id_usuario"`
    IDRecurso    uint           `gorm:"not null" json:"id_recurso"`
    FechaInicio  time.Time      `gorm:"not null" json:"fecha_inicio"`
    FechaFin     time.Time      `gorm:"not null" json:"fecha_fin"`
    EstadoReserva string        `gorm:"size:20;default:confirmada;not null" json:"estado_reserva"`
    Usuario      Usuario        `gorm:"foreignKey:IDUsuario" json:"-"`
    Recurso      Recurso        `gorm:"foreignKey:IDRecurso" json:"-"`
    CreatedAt    time.Time      `json:"created_at"`
    UpdatedAt    time.Time      `json:"updated_at"`
    DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}
MODEL_RESERVA

# models/adjunto.go
cat > models/adjunto.go <<'MODEL_ADJUNTO'
package models

import (
    "time"

    "gorm.io/gorm"
)

type Adjunto struct {
    ID        uint           `gorm:"primaryKey" json:"id"`
    ReservaID uint           `gorm:"not null;index" json:"reserva_id"`
    Nombre    string         `gorm:"size:255;not null" json:"nombre"`
    MimeType  string         `gorm:"size:100;not null" json:"mime_type"`
    Tamanio   int64          `gorm:"not null" json:"tamanio"`
    CephOID   string         `gorm:"size:255;not null;uniqueIndex" json:"ceph_oid"`
    CreatedAt time.Time      `json:"created_at"`
    UpdatedAt time.Time      `json:"updated_at"`
    DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
MODEL_ADJUNTO

# middleware/auth.go
cat > middleware/auth.go <<'MIDDLEWARE'
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

func AuthRequired(secret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token requerido"})
            return
        }

        tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
        token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
            if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, jwt.ErrSignatureInvalid
            }
            return []byte(secret), nil
        })

        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token inválido"})
            return
        }

        claims, _ := token.Claims.(jwt.MapClaims)
        c.Set("user_id", uint(claims["sub"].(float64)))
        c.Next()
    }
}
MIDDLEWARE

# middleware/metrics.go
cat > middleware/metrics.go <<'MIDDLEWARE_METRICS'
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
        Help: "Total de requests HTTP por metodo, ruta y status",
    }, []string{"method", "path", "status"})

    httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "http_request_duration_seconds",
        Help:    "Duracion de requests HTTP en segundos",
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
MIDDLEWARE_METRICS

# handlers/health.go
cat > handlers/health.go <<'HANDLER_HEALTH'
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
HANDLER_HEALTH

# handlers/auth.go
cat > handlers/auth.go <<'HANDLER_AUTH'
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
HANDLER_AUTH

# handlers/recursos.go
cat > handlers/recursos.go <<'HANDLER_RECURSOS'
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
HANDLER_RECURSOS

# handlers/reservas.go
cat > handlers/reservas.go <<'HANDLER_RESERVAS'
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
HANDLER_RESERVAS

# handlers/adjuntos.go
cat > handlers/adjuntos.go <<'HANDLER_ADJUNTOS'
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

    c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", adjunto.Nombre))
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
HANDLER_ADJUNTOS

# handlers/metrics.go
cat > handlers/metrics.go <<'HANDLER_METRICS'
package handlers

import (
    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
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
HANDLER_METRICS

# storage/ceph.go
mkdir -p storage
cat > storage/ceph.go <<'STORAGE_CEPH'
package storage

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func InitCeph() error {
	if _, err := exec.LookPath("rados"); err != nil {
		return fmt.Errorf("comando rados no encontrado: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	_, err := radosWithContext(ctx, "ls")
	if err != nil {
		fmt.Printf("WARNING: Ceph no disponible en inicio (continuando): %v\n", err)
	}
	return nil
}

const (
	poolName    = "reservas-pool"
	cephName    = "client.reservas"
	cephConf    = "/etc/ceph/ceph.conf"
	cephKeyring = "/etc/ceph/ceph.client.reservas.keyring"
	cmdTimeout  = 30 * time.Second
)

func radosWithContext(ctx context.Context, args ...string) (string, error) {
	cmdArgs := []string{"-p", poolName, "--name", cephName, "--conf", cephConf, "--keyring", cephKeyring}
	cmdArgs = append(cmdArgs, args...)
	cmd := exec.CommandContext(ctx, "rados", cmdArgs...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("rados error: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return strings.TrimSpace(out.String()), nil
}

func rados(args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	return radosWithContext(ctx, args...)
}

func UploadFile(oid string, data []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "rados",
		"-p", poolName,
		"--name", cephName,
		"--conf", cephConf,
		"--keyring", cephKeyring,
		"put", oid, "-",
	)
	cmd.Stdin = bytes.NewReader(data)
	var out bytes.Buffer
	cmd.Stderr = &out
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error subiendo archivo a Ceph: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return nil
}

func DownloadFile(oid string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "rados",
		"-p", poolName,
		"--name", cephName,
		"--conf", cephConf,
		"--keyring", cephKeyring,
		"get", oid, "-",
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("error descargando archivo de Ceph: %w\n%s", err, strings.TrimSpace(out.String()))
	}
	return out.Bytes(), nil
}

func DeleteFile(oid string) error {
	_, err := rados("rm", oid)
	return err
}

func ListFiles() ([]string, error) {
	out, err := rados("ls")
	if err != nil {
		return nil, err
	}
	if out == "" {
		return []string{}, nil
	}
	return strings.Split(out, "\n"), nil
}
STORAGE_CEPH

# main.go
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
        log.Printf("Advertencia: Error inicializando Ceph: %v", err)
    }

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

        // Adjuntos (protegido)
        protected.POST("/reservas/:id/adjunto", handlers.SubirAdjunto)
        protected.GET("/reservas/:id/adjuntos", handlers.ListarAdjuntos)
    }

    // Adjuntos (público para descarga por ID)
    r.GET("/api/v1/adjuntos/:id/descargar", handlers.DescargarAdjunto)
    r.DELETE("/api/v1/adjuntos/:id", middleware.AuthRequired(cfg.JWTSecret), handlers.EliminarAdjunto)

    log.Printf("Servidor iniciando en :%s", cfg.AppPort)
    if err := r.Run(":" + cfg.AppPort); err != nil {
        log.Fatalf("Error iniciando servidor: %v", err)
    }
}
MAIN

echo "  OK: código fuente escrito"

# ─── 7. Compilar ──────────────────────────────────────────────────────────────
echo "[7/9] Compilando binario..."
export PATH=$PATH:/usr/local/go/bin
go mod tidy
go build -o reservas-api .
echo "  OK: binario compilado"

# ─── 8. Probar conexión a DB y arrancar ───────────────────────────────────────
echo "[8/9] Probando conexión a PostgreSQL..."
timeout 30 ./reservas-api &
PID=$!
sleep 3
if curl -s http://localhost:8080/api/v1/health | grep -q "healthy"; then
    echo "  OK: API respondiendo correctamente"
else
    echo "  WARN: API no respondió en tiempo — verificar logs"
fi
kill $PID 2>/dev/null || true

# ─── 9. Servicio systemd ──────────────────────────────────────────────────────
echo "[9/9] Creando servicio systemd..."
cat > /etc/systemd/system/reservas-api.service <<'SYSTEMD'
[Unit]
Description=Reservas API - Go + Gin
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app/reservas-api
ExecStart=/app/reservas-api/reservas-api
Restart=always
RestartSec=5
EnvironmentFile=/app/reservas-api/.env

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable reservas-api
systemctl start reservas-api
sleep 2
echo "  Status: $(systemctl is-active reservas-api)"

echo ""
echo "=========================================="
echo "  API Go + Gin configurada exitosamente"
echo "=========================================="
echo ""
echo "Endpoints disponibles:"
echo "  GET  /api/v1/health"
echo "  POST /api/v1/auth/register"
echo "  POST /api/v1/auth/login"
echo "  GET  /api/v1/recursos"
echo "  GET  /api/v1/recursos/:id"
echo "  POST /api/v1/recursos          (requiere JWT)"
echo "  PUT  /api/v1/recursos/:id      (requiere JWT)"
echo "  DELETE /api/v1/recursos/:id    (requiere JWT)"
echo "  GET  /api/v1/reservas          (requiere JWT)"
echo "  POST /api/v1/reservas          (requiere JWT)"
echo "  GET  /api/v1/reservas/:id      (requiere JWT)"
echo "  DELETE /api/v1/reservas/:id    (requiere JWT)"
echo "  POST /api/v1/reservas/:id/adjunto   (requiere JWT)"
echo "  GET  /api/v1/reservas/:id/adjuntos  (requiere JWT)"
echo "  GET  /api/v1/adjuntos/:id/descargar"
echo "  DELETE /api/v1/adjuntos/:id     (requiere JWT)"
echo ""
echo "Para verificar:"
echo "  sudo incus exec api -- curl -s http://localhost:8080/api/v1/health"
echo ""

API_GO

echo "Script completado"
