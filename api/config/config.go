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
