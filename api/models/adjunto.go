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
