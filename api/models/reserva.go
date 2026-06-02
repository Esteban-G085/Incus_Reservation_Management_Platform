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
