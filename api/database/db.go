package database

import (
    "log"
    "time"

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
            log.Println("Conexion a PostgreSQL establecida")
            return
        }
        log.Printf("Esperando PostgreSQL (intento %d/30): %v", i+1, err)
        time.Sleep(2 * time.Second)
    }
    log.Fatalf("No se pudo conectar a PostgreSQL tras 30 intentos: %v", err)
}

func Migrate(models ...interface{}) {
    if err := DB.AutoMigrate(models...); err != nil {
        log.Fatalf("Error en migracion: %v", err)
    }
    log.Println("Migraciones completadas")
}
