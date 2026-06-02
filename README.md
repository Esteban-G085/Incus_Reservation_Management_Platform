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
- [Proxy devices (acceso desde el host)](#proxy-devices-acceso-desde-el-host)
- [Uso desde Windows](#uso-desde-windows)
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
              └── lab-net (10.10.0.0/24, sin NAT)
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

Puedes obtener los archivos del proyecto de dos formas: mediante Git (automatizado) o de forma manual descargando un ZIP (sin necesidad de Git).

### Opción A: Vía Git (Recomendada)

```bash
sudo apt update && sudo apt install -y git curl gpg
git clone https://github.com/Esteban-G085/Incus_Reservation_Management_Platform "$HOME/Incus_Reservation_Management_Platform"
cd "$HOME/Incus_Reservation_Management_Platform"
```

### Opción B: Forma Manual / Sin Git (Descarga de ZIP)

Si no deseas usar `git`, puedes descargar el código fuente y extraerlo manualmente:

```bash
sudo apt update && sudo apt install -y curl unzip gpg
wget https://github.com/Esteban-G085/Incus_Reservation_Management_Platform/archive/refs/heads/main.zip -O lab.zip
unzip lab.zip
mv Incus_Reservation_Management_Platform-main "$HOME/Incus_Reservation_Management_Platform"
cd "$HOME/Incus_Reservation_Management_Platform"
rm ../lab.zip
```

---

### Paso Final: Instalación y Despliegue Automático

Una vez dentro de la carpeta del proyecto, ejecuta la instalación de Incus y la creación del laboratorio:

```bash
# 1. Instalar Incus (vía Zabbly)
sudo bash scripts/incusinstall.sh

# 2. Inicializar Incus
sudo incus admin init --minimal

# 3. Desplegar la infraestructura base (Red, Perfiles, Volúmenes, Contenedores)
sudo bash scripts/setup-lab.sh

# 4. Configurar Servicios internos (Ansible, PostgreSQL, Prometheus, API)
sudo bash scripts/setup-services.sh

# 5. Configurar proxy devices para acceso desde el host
sudo bash scripts/containers.sh

# 6. Validar el despliegue
sudo bash scripts/validate.sh
```

Resultado esperado: 6 contenedores en estado `RUNNING` con IPs en `10.10.0.x`, volúmenes atachados, y servicios internos respondiendo adecuadamente.

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
├── start-lab.bat               # Inicio completo desde Windows
├── startup.bat                 # Inicio rápido desde Windows
├── shutdown.bat                # Apagado desde Windows
├── validate.bat                # Validación desde Windows
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
| NAT | Deshabilitado |
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

## Proxy devices (acceso desde el host)

Incus proxy devices permiten mapear puertos del contenedor al host. Se crean automáticamente con `scripts/containers.sh`:

```text
core:5173  → localhost:5173  (Frontend)
api:8080   → localhost:8080  (API REST)
mon:9090   → localhost:9090  (Prometheus)
```

Verificar con:

```bash
incus config device show api
incus config device show core
incus config device show mon
```

Los proxy devices se pierden si el contenedor se recrea. Vuelve a ejecutar `scripts/containers.sh` o usa los scripts `.bat` desde Windows.

---

## Uso desde Windows

### Requisitos

- Windows 11 con **WSL 2**
- Distribución **Debian** (o compatible) con Incus instalado
- PowerShell (administrador)

### Scripts disponibles

| Script | Descripción |
|---|---|
| `start-lab.bat` | Inicio completo: verifica WSL, arranca Incus + contenedores, crea proxy devices, espera puertos (5173, 8080, 9090), abre el navegador |
| `startup.bat` | Inicio rápido: solo arranca contenedores + proxy devices |
| `shutdown.bat` | Apagado ordenado de todos los contenedores |
| `validate.bat` | Validación: verifica WSL, estado de Incus y conectividad HTTP a los 3 servicios |

> Ejecutar como **Administrador** para acceso al socket de Incus y proxy devices.

### Uso típico

```cmd
# Iniciar el laboratorio
start-lab.bat

# Validar que todo funciona
validate.bat

# Apagar
shutdown.bat
```

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

---

## Documentación de referencia

| Archivo | Contenido |
|---|---|
| `infraestructura.md` | Justificación técnica de Debian 13, matriz de decisión, y detalles minuciosos del funcionamiento de cada Script. (Documento Base) |
| `choices.md` | Log de todos los cambios con fecha, archivos afectados y razón |

---

*Proyecto académico — Plataforma de Gestión de Reservas — Junio 2026*
