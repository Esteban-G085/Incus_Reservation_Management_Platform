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
