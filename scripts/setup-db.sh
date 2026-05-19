#!/bin/bash
# setup-db.sh - Configuración completa de PostgreSQL en contenedor db

set -e  # Salir si algo falla

echo "=========================================="
echo "  CONFIGURACIÓN DE PostgreSQL - db"
echo "=========================================="
echo ""

# Ejecutar todo dentro del contenedor db
sudo incus exec db -- bash <<'DB_COMMANDS'

set -e

echo "[1/8] Actualizando sistema..."
apt update -qq > /dev/null 2>&1
apt upgrade -y -qq > /dev/null 2>&1

echo "[2/8] Instalando PostgreSQL..."
apt install -y postgresql postgresql-contrib postgresql-client > /dev/null 2>&1

echo "[3/8] Iniciando servicio PostgreSQL..."
systemctl start postgresql > /dev/null 2>&1
systemctl enable postgresql > /dev/null 2>&1

echo "[4/8] Configurando PostgreSQL para escuchar en todas las interfaces..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/15/main/postgresql.conf

echo "[5/8] Configurando autenticacion para red 10.100.0.0/24..."
echo "host    all             all             10.100.0.0/24           md5" >> /etc/postgresql/15/main/pg_hba.conf

echo "[6/8] Reiniciando PostgreSQL..."
systemctl restart postgresql > /dev/null 2>&1

echo "[7/8] Creando usuario y base de datos..."
sudo -u postgres psql <<EOF > /dev/null 2>&1
CREATE USER reservas_user WITH PASSWORD 'SecurePassword123!';
CREATE DATABASE reservas_db OWNER reservas_user;
GRANT ALL PRIVILEGES ON DATABASE reservas_db TO reservas_user;
ALTER USER reservas_user CREATEDB;
EOF

echo "[8/8] Verificando conexion..."
psql -U reservas_user -d reservas_db -h localhost -c "SELECT 1 AS conectado;" > /dev/null 2>&1

echo ""
echo "=========================================="
echo "PostgreSQL configurado exitosamente"
echo "=========================================="
echo ""
echo "Credenciales:"
echo "  Usuario: reservas_user"
echo "  Contraseña: SecurePassword123!"
echo "  Base de datos: reservas_db"
echo "  Host: db:5432"
echo ""
echo "Para validar conectividad remota ejecuta:"
echo "  sudo incus exec app-api -- psql -U reservas_user -d reservas_db -h db -c 'SELECT 1;'"
echo ""

DB_COMMANDS

echo "Script completado"