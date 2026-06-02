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
