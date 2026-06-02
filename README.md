# Incus_Reservation_Management_Platform

Laboratorio de microservicios basado en contenedores **Incus** sobre **Debian 13 (Trixie)** para una plataforma de gestión de reservas. Diseñado para entornos académicos con hardware modesto.

---

## Índice

- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Despliegue](#despliegue)
- [Estado actual](#estado-actual)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Red](#red)
- [Perfiles de recursos](#perfiles-de-recursos)
- [Volúmenes persistentes](#volúmenes-persistentes)
- [Configuración de Servicios (Ansible)](#configuración-de-servicios-ansible)
- [API REST (Go + Gin)](#api-rest-go--gin)
- [Pendiente](#pendiente)
- [Operación del laboratorio](#operación-del-laboratorio)
- [Documentación de referencia](#documentación-de-referencia)

---

## Arquitectura

```
Host: Windows 11 + WSL 2 (Debian 13)
       │
       ├── localhost:5173  → proxy device → core (Frontend React)
       ├── localhost:8080  → proxy device → api   (REST API Go)
       ├── localhost:9090  → proxy device → mon   (Prometheus)
       │
       └── Incus + OVN
              │
              └── lab-net (10.10.0.0/24, con NAT)
                     │
          ┌──────────┬──────────┬──────────┬─────────┬─────────┐
          │          │          │          │         │         │
        [ctl]      [api]      [core]     [db]      [mon]    [ceph]
      .0.2/24    .0.3/24    .0.4/24   .0.5/24   .0.6/24  .0.7/24
   Orquestación  REST API   Frontend  PostgreSQL Prom+Graf  Ceph
```

---

## Requisitos

| Componente | Mínimo recomendado |
|---|---|
| CPU | 4 cores |
| RAM | 8 GB (el lab usa ~1.1 GB en idle) |
| Almacenamiento | 20 GB SSD |
| OS Host | Windows 11 + WSL 2 (Debian 13) o Debian 13 baremetal |

> Los perfiles definen topes máximos (cgroups), no reservas. Los contenedores solo consumen lo que necesitan.

---

## Despliegue

> **Guía completa — Desde WSL hasta la plataforma funcionando**

### 1. Instalar WSL2 y Debian

En PowerShell (como Administrador):

```powershell
# Habilitar WSL
wsl --install

# Instalar Debian
wsl --install -d Debian

# Configurar WSL2 como versión por defecto
wsl --set-default-version 2

# Verificar
wsl -l -v
# → Debian    Running    2
```

Al entrar por primera vez, crea un usuario (ej. `esteban`) con contraseña.

### 2. Clonar el repositorio desde WSL

Dentro de la terminal de Debian (WSL):

```bash
# Instalar git si no está
sudo apt update && sudo apt install -y git

# Clonar el repositorio
git clone https://github.com/Esteban-G085/Incus_Reservation_Management_Platform.git
cd Incus_Reservation_Management_Platform
```

> **Nota:** Los `.sh` ya están en LF en el repo, pero si clonaste con git en WSL no debería haber problema con CRLF.

### 3. Instalar Incus

```bash
sudo bash scripts/incusinstall.sh
# o manualmente:
sudo apt install -y incus
sudo incus admin init --minimal
```

### 4. Crear perfiles, red y contenedores

```bash
# 4a. Perfiles de recursos
sudo bash scripts/profiles.sh

# 4b. Red interna (lab-net, 10.100.0.0/24)
sudo bash scripts/network.sh

# 4c. Volúmenes de datos persistentes
sudo bash scripts/volumes.sh

# 4d. Crear los 7 contenedores
sudo bash scripts/setup.sh

# 4e. Arrancar todos los contenedores
sudo bash scripts/startup.sh
```

Esto despliega:

| Contenedor | IP | Rol |
|---|---|---|
| ceph | 10.100.0.2 | Almacenamiento Ceph |
| db | 10.100.0.5 | PostgreSQL |
| mon | 10.100.0.6 | Prometheus + Grafana |
| core | 10.100.0.4 | Frontend React |
| api | 10.100.0.3 | API Go |
| ctl | 10.100.0.7 | Control/Herramientas |
| adm | — | Administración |

### 5. Configurar Ceph

```bash
# Temporal: 4 GB para crear el OSD
sudo incus profile set ceph limits.memory=4096MiB

# Ejecutar setup
sudo bash scripts/setup-ceph.sh
```

> [!WARNING]
> **Bug conocido en Ceph 18+:** El paso 6 falla por UUID mismatch. Si ocurre, ejecuta el workaround detallado en la [sección 5b](#5b-workaround-si-falla-osd).

```bash
# Restaurar memoria
sudo incus profile set ceph limits.memory=2048MiB
```

### 5b. Workaround si falla OSD

```bash
sudo incus exec ceph -- bash -c "
set -e
systemctl stop ceph-osd@0 2>/dev/null || true
rm -rf /var/lib/ceph/osd/ceph-*
ceph osd rm 0 2>/dev/null || true

OSD_UUID=\$(uuidgen)
OSD_ID=0
ceph osd create \$OSD_UUID \$OSD_ID

mkdir -p /var/lib/ceph/osd/ceph-\${OSD_ID}
ln -sf /var/lib/ceph/osd.img /var/lib/ceph/osd/ceph-\${OSD_ID}/block
chown -h ceph:ceph /var/lib/ceph/osd/ceph-\${OSD_ID}/block

ceph-osd --mkfs -i \$OSD_ID --osd-uuid \$OSD_UUID --conf /etc/ceph/ceph.conf --osd-data /var/lib/ceph/osd/ceph-\${OSD_ID} --setuser ceph --setgroup ceph
ceph auth get-or-create osd.\${OSD_ID} mon 'allow profile osd' osd 'allow *' -o /var/lib/ceph/osd/ceph-\${OSD_ID}/keyring
systemctl enable ceph-osd@\${OSD_ID}
systemctl start ceph-osd@\${OSD_ID}
"

sudo incus exec ceph -- ceph -s
# Debe mostrar: 1 osds: 1 up, 1 in, 32 pgs active+clean
```

### 6. Configurar clientes Ceph

```bash
sudo bash scripts/setup-ceph-client.sh
```

### 7. Configurar base de datos PostgreSQL

```bash
sudo bash scripts/setup-db.sh
```

### 8. Compilar y arrancar la API Go

```bash
sudo bash scripts/setup-api-go.sh
```

### 9. Configurar el frontend React

```bash
sudo bash scripts/setup-frontend.sh
```

### 10. Configurar monitoreo (Prometheus + Grafana)

```bash
# Prometheus
sudo bash scripts/setup-metrics.sh

# Grafana
sudo bash scripts/setup-grafana.sh
```

### 11. Exponer puertos al host Windows

Para acceder desde el navegador en Windows. Ejecuta en PowerShell (como usuario normal):

```powershell
wsl -d Debian -u root -e incus config device add api api-port proxy connect=tcp:127.0.0.1:8080 listen=tcp:0.0.0.0:8080
wsl -d Debian -u root -e incus config device add core frontend-port proxy connect=tcp:127.0.0.1:5173 listen=tcp:0.0.0.0:5173
wsl -d Debian -u root -e incus config device add mon prometheus-port proxy connect=tcp:127.0.0.1:9090 listen=tcp:0.0.0.0:9090
wsl -d Debian -u root -e incus config device add mon grafana-port proxy connect=tcp:127.0.0.1:3000 listen=tcp:0.0.0.0:3000
```

### 12. Arranque limpio y verificación final

```bash
# En WSL (Debian):
sudo bash scripts/shutdown.sh
sleep 10
sudo bash scripts/startup.sh
sudo bash scripts/validate.sh
```

### 13. Probar desde Windows

Abre en el navegador:

| Servicio | URL | Credenciales |
|---|---|---|
| Frontend | `http://localhost:5173` | — |
| API | `http://localhost:8080/api/v1/health` | — |
| Prometheus | `http://localhost:9090` | — |
| Grafana | `http://localhost:3000` | `admin` / `admin` |

---

## Estado actual

### Infraestructura base

| Componente | Estado |
|---|---|
| Instalación de Incus (Zabbly) | ✅ |
| Perfiles de recursos (6 perfiles) | ✅ |
| Red OVN `lab-net` (10.10.0.0/24) | ✅ |
| Volúmenes persistentes (5 volúmenes) | ✅ |
| Contenedores Debian 13 (6 nodos) | ✅ |
| Validación de conectividad | ✅ |

### Servicios configurados

| Contenedor | Servicio | Stack | Estado |
|---|---|---|---|
| ctl | Orquestación | Ansible base | ✅ |
| api | REST API | **Go + Gin** (JWT, CRUD, Ceph) | ✅ (activo) |
| core | Frontend | **React + Vite** | ✅ (activo) |
| db | Base de datos | PostgreSQL 15 | ✅ (activo) |
| mon | Métricas | Prometheus + Grafana | ✅ (activo) |
| ceph | Almacenamiento distribuido | Ceph (MON+MGR+OSD+pool) | ✅ (activo) |

### Acceso desde el host

| Servicio | URL (host) | Proxy device |
|---|---|---|
| Frontend (React) | `http://localhost:5173` | `core:5173` |
| API REST (Go) | `http://localhost:8080` | `api:8080` |
| Prometheus | `http://localhost:9090` | `mon:9090` |

---

## Estructura del repositorio

```text
Incus_Reservation_Management_Platform/
├── README.md                   # Este archivo
├── choices.md                  # Log de cambios técnicos y estado del despliegue
├── infraestructura.md          # Documentación técnica y desglose de scripts
├── setupnetwork.md             # Guía de la estructura teórica OVN
├── api/                        # Código fuente de la API Go
│   ├── main.go                 # Punto de entrada
│   ├── go.mod / go.sum         # Dependencias Go
│   ├── .env.example            # Plantilla de configuración
│   ├── config/config.go        # Configuración del servidor
│   ├── database/db.go          # Conexión PostgreSQL con retry
│   ├── handlers/               # Handlers HTTP
│   │   ├── auth.go             #   Registro / Login
│   │   ├── recursos.go         #   CRUD recursos
│   │   ├── reservas.go         #   CRUD reservas
│   │   ├── adjuntos.go         #   Upload/Download/Delete Ceph
│   │   └── metrics.go          #   Métricas Prometheus
│   ├── middleware/             # Middleware
│   │   ├── auth.go             #   JWT validation
│   │   └── metrics.go          #   Prometheus metrics
│   ├── models/                 # Modelos GORM
│   │   ├── usuario.go
│   │   ├── recurso.go
│   │   ├── reserva.go
│   │   └── adjunto.go
│   └── storage/
│       └── ceph.go             # Integración con Ceph (rados CLI)
└── scripts/
    ├── incusinstall.sh         # Instalación de Incus desde Zabbly
    ├── network.sh              # Configuración OVN e infraestructura de red
    ├── profiles.sh             # Creación de perfiles de recursos
    ├── volumes.sh              # Creación de volúmenes persistentes
    ├── containers.sh           # Lanzamiento/configuración de contenedores + proxy devices
    ├── setup-services.sh       # Instalación de dependencias y ejecución de Ansible
    ├── setup-lab.sh            # Orquestador principal (llama a los scripts de infra)
    ├── setup-db.sh             # Configuración de PostgreSQL
    ├── setup-api-go.sh         # Configuración de API Go + Gin (desde repo o inline)
    ├── setup-frontend.sh       # Frontend React + Vite
    ├── setup-metrics.sh        # Métricas Prometheus + node_exporter
    ├── setup-grafana.sh        # Datasource y dashboards Grafana
    ├── setup-ceph.sh           # Cluster Ceph (MON+MGR+OSD+pool)
    ├── setup-ceph-client.sh    # Clientes Ceph en api/core
    ├── start-services.sh       # Arranque de servicios internos
    ├── validate.sh             # Validación de infraestructura
    ├── validate-services.sh    # Validación de servicios
    ├── shutdown.sh             # Apagado ordenado del laboratorio
    └── startup.sh              # Arranque ordenado del laboratorio
```

---

## Red

| Parámetro | Valor |
|---|---|
| Tipo | OVN (Open Virtual Network) |
| Nombre | `lab-net` |
| Subred | `10.10.0.0/24` |
| NAT | Habilitado |
| Rango DHCP/OVN | `10.10.0.2 – 10.10.0.250` |

---

## Perfiles de recursos

| Perfil | CPUs | RAM | Rol |
|---|---|---|---|
| ctl | 1 | 512 MiB | Orquestación |
| api | 2 | 1024 MiB | REST API |
| core | 2 | 1536 MiB | Frontend |
| db | 4 | 4096 MiB | PostgreSQL |
| mon | 2 | 1024 MiB | Prometheus + Grafana |
| ceph | 2 | 2048 MiB | Almacenamiento distribuido |

---

## Volúmenes persistentes

| Volumen | Montado en | Contenedor |
|---|---|---|
| `postgres-data` | `/var/lib/postgresql` | db |
| `prometheus-data` | `/prometheus` | mon |
| `grafana-data` | `/var/lib/grafana` | mon |
| `ceph-data` | `/var/lib/ceph` | ceph |
| `app-data` | `/app/data` | api, core |

---

## Configuración de Servicios (Ansible)

A diferencia de la gestión manual, todo el provisionamiento de software dentro de los contenedores está automatizado a través de Ansible.

El script `scripts/setup-services.sh` se encarga de:

1. Instalar Ansible en el host y la colección de Incus (`community.general`).
2. Instalar Python3 en todos los contenedores.
3. Generar dinámicamente un archivo de inventario `inventory.ini`.
4. Crear y ejecutar los Playbooks (`playbook-base.yml`, `playbook-db.yml`, `playbook-mon.yml`, `playbook-app.yml`).

Si en el futuro deseas re-ejecutar un aprovisionamiento o alterar una configuración, solo debes editar y ejecutar este script.

---

## API REST (Go + Gin)

La API está escrita en Go usando el framework **Gin** con **GORM** para la base de datos. Se ejecuta como servicio `systemd` dentro del contenedor `api`.

### Autenticación

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Registrar usuario (`email`, `password`) |
| `POST` | `/api/v1/auth/login` | Iniciar sesión, devuelve JWT |

### Recursos

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `GET` | `/api/v1/recursos` | No | Listar todos los recursos |
| `GET` | `/api/v1/recursos/:id` | No | Obtener recurso por ID |
| `POST` | `/api/v1/recursos` | JWT | Crear recurso |
| `PUT` | `/api/v1/recursos/:id` | JWT | Actualizar recurso |
| `DELETE` | `/api/v1/recursos/:id` | JWT | Eliminar recurso |

### Reservas

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `GET` | `/api/v1/reservas` | JWT | Listar reservas del usuario autenticado |
| `GET` | `/api/v1/reservas/:id` | JWT | Obtener reserva por ID |
| `POST` | `/api/v1/reservas` | JWT | Crear reserva |
| `PUT` | `/api/v1/reservas/:id` | JWT | Actualizar reserva |
| `DELETE` | `/api/v1/reservas/:id` | JWT | Cancelar reserva |

> `POST /api/v1/reservas` requiere: `{"id_recurso": 1, "fecha_inicio": "2026-06-01T10:00:00Z", "fecha_fin": "2026-06-01T12:00:00Z"}`. `id_usuario` se obtiene del JWT.

### Adjuntos (Ceph Storage)

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `POST` | `/api/v1/adjuntos/upload` | JWT | Subir archivo a Ceph (multipart form, campo `file`, campo `id_reserva`) |
| `GET` | `/api/v1/adjuntos/:oid` | JWT | Descargar archivo desde Ceph |
| `DELETE` | `/api/v1/adjuntos/:oid` | JWT | Eliminar archivo de Ceph |

> Los archivos se almacenan en el pool `reservas-pool` de Ceph con OID `reserva_{id}_{timestamp}.ext`.

### Health

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/v1/health` | Health check (DB + estado del servicio) |

### Métricas

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/metrics` | Métricas Prometheus (requests totales, duración, errores por endpoint) |

---

## Pendiente

### Conexión app → base de datos (✅ resuelto con setup-db.sh + setup-api-go.sh)
- [x] Crear usuario y base de datos en PostgreSQL (`reservas_db`, usuario `reservas_user`)
- [x] API Go + Gin con GORM conectada a PostgreSQL
- [x] Variables de entorno de conexión configuradas

### Servicios systemd (✅ resuelto con setup-api-go.sh + setup-frontend.sh)
- [x] Unit file para API Go (`reservas-api.service`)
- [x] Unit file para frontend React (`reservas-frontend.service`)

### Observabilidad (✅ resuelto con setup-metrics.sh + setup-grafana.sh)
- [x] Scraping Prometheus hacia `api`, `db`, `core`
- [x] Dashboards Grafana: Sistema y API Reservas
- [x] Datasource Prometheus en Grafana

### Almacenamiento (✅ resuelto con setup-ceph.sh + setup-ceph-client.sh + api/storage/ceph.go)
- [x] Cluster Ceph con MON + MGR + OSD (BlueStore, loop device 5GB)
- [x] Pool `reservas-pool` con keyring `client.reservas`
- [x] Clientes Ceph configurados en `api` y `core`
- [x] Upload / Download / Delete de adjuntos desde la API Go hacia Ceph (rados CLI)
- [x] Tiempo de espera con context timeout (30s) en todas las operaciones Ceph

### Estabilidad de la API
- [x] Retry loop (30 intentos, 2s) para esperar PostgreSQL al arrancar
- [x] `InitCeph` no fatal: si Ceph no responde, la API igual se inicia
- [x] Context timeout (30s) en todos los comandos `rados`

---

## Operación del laboratorio

### Arranque Completo

```bash
sudo bash scripts/startup.sh
```

El script inicia los contenedores garantizando dependencias: `ceph` (storage) → `db` → `mon` → `core` → `api` → `ctl`.

### Apagado Ordenado

```bash
sudo bash scripts/shutdown.sh
```

Detiene servicios permitiendo la bajada a disco y evitando corrupción: `api` → `core` → `mon` → `db` → `ceph` → `ctl`.

### Verificación

```bash
sudo bash scripts/validate.sh
```

---

## Documentación de referencia

| Archivo | Contenido |
|---|---|
| `infraestructura.md` | Justificación técnica de Debian 13, matriz de decisión, y detalles minuciosos del funcionamiento de cada Script. (Documento Base) |
| `choices.md` | Log de todos los cambios con fecha, archivos afectados y razón |

---

*Proyecto académico — Plataforma de Gestión de Reservas — Junio 2026*
