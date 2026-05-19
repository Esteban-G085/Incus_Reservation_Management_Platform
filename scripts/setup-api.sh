#!/bin/bash
# setup-api.sh - Configuración completa de Flask API en contenedor app-api

set -e  # Salir si algo falla

echo "=========================================="
echo "  CONFIGURACIÓN DE Flask API - app-api"
echo "=========================================="
echo ""

# Ejecutar todo dentro del contenedor app-api
sudo incus exec app-api -- bash <<'API_COMMANDS'

set -e

echo "[1/10] Actualizando sistema..."
apt update -qq > /dev/null 2>&1
apt upgrade -y -qq > /dev/null 2>&1

echo "[2/10] Instalando dependencias del sistema..."
apt install -y \
  python3.11 \
  python3.11-venv \
  python3-pip \
  git \
  curl \
  build-essential \
  libpq-dev \
  postgresql-client > /dev/null 2>&1

echo "[3/10] Creando estructura de directorios..."
mkdir -p /app/reservas-api
cd /app/reservas-api

echo "[4/10] Creando entorno virtual Python..."
python3.11 -m venv venv > /dev/null 2>&1
source venv/bin/activate

echo "[5/10] Actualizando pip..."
pip install --upgrade pip setuptools wheel -q > /dev/null 2>&1

echo "[6/10] Instalando dependencias Python..."
cat > requirements.txt <<'REQUIREMENTS'
Flask>=3.0.0
Flask-SQLAlchemy>=3.1.1
Flask-JWT-Extended>=4.7.0
Flask-RESTX>=1.3.2
Flask-Migrate>=4.0.7
SQLAlchemy>=2.0.30
psycopg2-binary>=2.9.10
python-dotenv==1.0.0
bcrypt>=4.1.3
pydantic>=2.9.0
marshmallow>=3.22.0
prometheus-client>=0.20.0
python-json-logger>=2.0.7
pytest>=8.2.0
pytest-cov>=5.0.0
pytest-flask>=1.3.0
REQUIREMENTS

pip install -r requirements.txt -q > /dev/null 2>&1

echo "[7/10] Creando archivo .env..."
cat > .env <<'ENV_FILE'
# Flask
FLASK_ENV=development
FLASK_APP=run.py
FLASK_DEBUG=1

# Base de Datos
DATABASE_URL=postgresql://reservas_user:SecurePassword123!@db:5432/reservas_db

# JWT
JWT_SECRET_KEY=reservas-secret-key-$(date +%s)
JWT_ACCESS_TOKEN_EXPIRES=86400
ENV_FILE

echo "[8/10] Creando estructura Flask..."
mkdir -p app/{models,routes}

# Crear app/__init__.py
cat > app/__init__.py <<'APP_INIT'
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager

db = SQLAlchemy()
jwt = JWTManager()

def create_app():
    app = Flask(__name__)
    
    # Cargar configuración desde .env
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        raise ValueError("DATABASE_URL no está configurado en .env")
    
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'secret-key')
    
    # Inicializar extensiones
    db.init_app(app)
    jwt.init_app(app)
    
    # Crear contexto y tablas
    with app.app_context():
        try:
            db.create_all()
        except Exception as e:
            print(f"Error creando tablas: {e}")
    
    # Registrar rutas básicas
    from app.routes import health_bp
    app.register_blueprint(health_bp)
    
    return app
APP_INIT

# Crear app/models/__init__.py
cat > app/models/__init__.py <<'MODELS'
from app import db
import bcrypt

class Usuario(db.Model):
    __tablename__ = 'usuario'
    
    id_usuario = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.Text, nullable=False)
    
    def set_password(self, password):
        salt = bcrypt.gensalt(rounds=10)
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def check_password(self, password):
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
    
    def to_dict(self):
        return {
            'id_usuario': self.id_usuario,
            'nombre': self.nombre,
            'email': self.email
        }

class Recurso(db.Model):
    __tablename__ = 'recurso'
    
    id_recurso = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    tipo = db.Column(db.String(50), nullable=False)
    estado = db.Column(db.String(20), default='disponible', nullable=False)
    
    def to_dict(self):
        return {
            'id_recurso': self.id_recurso,
            'nombre': self.nombre,
            'tipo': self.tipo,
            'estado': self.estado
        }

class Reserva(db.Model):
    __tablename__ = 'reserva'
    
    id_reserva = db.Column(db.Integer, primary_key=True)
    id_usuario = db.Column(db.Integer, db.ForeignKey('usuario.id_usuario'), nullable=False)
    id_recurso = db.Column(db.Integer, db.ForeignKey('recurso.id_recurso'), nullable=False)
    fecha_inicio = db.Column(db.DateTime, nullable=False)
    fecha_fin = db.Column(db.DateTime, nullable=False)
    estado_reserva = db.Column(db.String(20), default='confirmada', nullable=False)
    
    def to_dict(self):
        return {
            'id_reserva': self.id_reserva,
            'id_usuario': self.id_usuario,
            'id_recurso': self.id_recurso,
            'fecha_inicio': self.fecha_inicio.isoformat(),
            'fecha_fin': self.fecha_fin.isoformat(),
            'estado_reserva': self.estado_reserva
        }
MODELS

# Crear app/routes.py
cat > app/routes.py <<'ROUTES'
from flask import Blueprint, jsonify
from datetime import datetime

health_bp = Blueprint('health', __name__)

@health_bp.route('/api/v1/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'reservas-api'
    }), 200
ROUTES

# Crear run.py
cat > run.py <<'RUN_PY'
import os
from dotenv import load_dotenv

# Cargar .env ANTES de importar la app
load_dotenv()

from app import create_app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True)
RUN_PY

echo "[9/10] Probando conexión a PostgreSQL..."
source venv/bin/activate
python3 <<'PYTHON_TEST'
import os
from dotenv import load_dotenv

load_dotenv()

db_url = os.getenv('DATABASE_URL')
print(f"  DATABASE_URL: {db_url}")

try:
    from app import create_app, db
    app = create_app()
    with app.app_context():
        result = db.session.execute(db.text("SELECT 1 AS test"))
        print(f"Conexión a PostgreSQL exitosa")
        
        tables = db.inspect(db.engine).get_table_names()
        print(f"Tablas creadas: {', '.join(tables)}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYTHON_TEST

echo "[10/10] Creando servicio systemd..."
cat > /etc/systemd/system/reservas-api.service <<'SYSTEMD'
[Unit]
Description=Reservas API Flask
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app/reservas-api
Environment="PATH=/app/reservas-api/venv/bin"
ExecStart=/app/reservas-api/venv/bin/python run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload > /dev/null 2>&1
systemctl enable reservas-api > /dev/null 2>&1
systemctl start reservas-api > /dev/null 2>&1

echo ""
echo "=========================================="
echo "Flask API configurada exitosamente"
echo "=========================================="
echo ""
echo "Directorios creados:"
echo "  /app/reservas-api/"
echo "  /app/reservas-api/app/models"
echo "  /app/reservas-api/app/routes"
echo ""
echo "Archivos creados:"
echo "  .env (credenciales)"
echo "  requirements.txt"
echo "  run.py"
echo "  app/__init__.py"
echo "  app/models/__init__.py"
echo "  app/routes.py"
echo ""
echo "Servicio systemd: reservas-api"
echo "Status: $(systemctl is-active reservas-api)"
echo ""
echo "Para verificar logs:"
echo "  sudo incus exec app-api -- journalctl -u reservas-api -f"
echo ""
echo "Para probar la API:"
echo "  sudo incus exec app-api -- curl -s http://localhost:5000/api/v1/health"
echo ""

API_COMMANDS

echo "Script completado"