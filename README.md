# Incus_Reservation_Management_Platform

Laboratorio de microservicios basado en contenedores **Incus** sobre **Debian 13 (Trixie)** para una plataforma de gesti??n de reservas. Dise??ado para entornos acad??micos con hardware modesto.

---

## ??ndice

- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Despliegue](#despliegue)
- [Estado actual](#estado-actual)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Red](#red)
- [Perfiles de recursos](#perfiles-de-recursos)
- [Vol??menes persistentes](#vol??menes-persistentes)
- [Configuraci??n de Servicios (Ansible)](#configuraci??n-de-servicios-ansible)
- [API REST (Go + Gin)](#api-rest-go--gin)
- [Proxy devices (acceso desde el host)](#proxy-devices-acceso-desde-el-host)
- [Uso desde Windows](#uso-desde-windows)
- [Pendiente](#pendiente)
- [Operaci??n del laboratorio](#operaci??n-del-laboratorio)
- [Documentaci??n de referencia](#documentaci??n-de-referencia)

---

## Arquitectura

```
Host: Windows 11 + WSL 2 (Debian 13)
       ???
       ????????? localhost:5173  ??? proxy device ??? core (Frontend React)
       ????????? localhost:8080  ??? proxy device ??? api   (REST API Go)
       ????????? localhost:9090  ??? proxy device ??? mon   (Prometheus)
       ???
       ????????? Incus + OVN
              ???
              ????????? lab-net (10.10.0.0/24, sin NAT)
                     ???
          ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
          ???          ???          ???          ???         ???         ???
        [ctl]      [api]      [core]     [db]      [mon]    [ceph]
      .0.2/24    .0.3/24    .0.4/24   .0.5/24   .0.6/24  .0.7/24
   Orquestaci??n  REST API   Frontend  PostgreSQL Prom+Graf  Ceph
```

---

## Requisitos

| Componente | M??nimo recomendado |
|---|---|
| CPU | 4 cores |
| RAM | 8 GB (el lab usa ~1.1 GB en idle) |
| Almacenamiento | 20 GB SSD |
| OS Host | Windows 11 + WSL 2 (Debian 13) o Debian 13 baremetal |

> Los perfiles definen topes m??ximos (cgroups), no reservas. Los contenedores solo consumen lo que necesitan.

---

## Despliegue

Puedes obtener los archivos del proyecto de dos formas: mediante Git (automatizado) o de forma manual descargando un ZIP (sin necesidad de Git).

### Opci??n A: V??a Git (Recomendada)

```bash
sudo apt update && sudo apt install -y git curl gpg
git clone https://github.com/Esteban-G085/Incus_Reservation_Management_Platform "$HOME/Incus_Reservation_Management_Platform"
cd "$HOME/Incus_Reservation_Management_Platform"
```

### Opci??n B: Forma Manual / Sin Git (Descarga de ZIP)

Si no deseas usar `git`, puedes descargar el c??digo fuente y extraerlo manualmente:

```bash
sudo apt update && sudo apt install -y curl unzip gpg
wget https://github.com/Esteban-G085/Incus_Reservation_Management_Platform/archive/refs/heads/main.zip -O lab.zip
unzip lab.zip
mv Incus_Reservation_Management_Platform-main "$HOME/Incus_Reservation_Management_Platform"
cd "$HOME/Incus_Reservation_Management_Platform"
rm ../lab.zip
```

---

### Paso Final: Instalaci??n y Despliegue Autom??tico

Una vez dentro de la carpeta del proyecto, ejecuta la instalaci??n de Incus y la creaci??n del laboratorio:

```bash
# 1. Instalar Incus (v??a Zabbly)
sudo bash scripts/incusinstall.sh

# 2. Inicializar Incus
sudo incus admin init --minimal

# 3. Desplegar la infraestructura base (Red, Perfiles, Vol??menes, Contenedores)
sudo bash scripts/setup-lab.sh

# 4. Configurar Servicios internos (Ansible, PostgreSQL, Prometheus, API)
sudo bash scripts/setup-services.sh

# 5. Configurar proxy devices para acceso desde el host
sudo bash scripts/containers.sh

# 6. Validar el despliegue
sudo bash scripts/validate.sh
```

Resultado esperado: 6 contenedores en estado `RUNNING` con IPs en `10.10.0.x`, vol??menes atachados, y servicios internos respondiendo adecuadamente.

---

## Estado actual

### Infraestructura base

| Componente | Estado |
|---|---|
| Instalaci??n de Incus (Zabbly) | ??? |
| Perfiles de recursos (6 perfiles) | ??? |
| Red OVN `lab-net` (10.10.0.0/24) | ??? |
| Vol??menes persistentes (5 vol??menes) | ??? |
| Contenedores Debian 13 (6 nodos) | ??? |
| Validaci??n de conectividad | ??? |

### Servicios configurados

| Contenedor | Servicio | Stack | Estado |
|---|---|---|---|
| ctl | Orquestaci??n | Ansible base | ??? |
| api | REST API | **Go + Gin** (JWT, CRUD, Ceph) | ??? (activo) |
| core | Frontend | **React + Vite** | ??? (activo) |
| db | Base de datos | PostgreSQL 15 | ??? (activo) |
| mon | M??tricas | Prometheus + Grafana | ??? (activo) |
| ceph | Almacenamiento distribuido | Ceph (MON+MGR+OSD+pool) | ??? (activo) |

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
????????? README.md                   # Este archivo
????????? choices.md                  # Log de cambios t??cnicos y estado del despliegue
????????? infraestructura.md          # Documentaci??n t??cnica y desglose de scripts
????????? setupnetwork.md             # Gu??a de la estructura te??rica OVN
????????? api/                        # C??digo fuente de la API Go
???   ????????? main.go                 # Punto de entrada
???   ????????? go.mod / go.sum         # Dependencias Go
???   ????????? .env.example            # Plantilla de configuraci??n
???   ????????? config/config.go        # Configuraci??n del servidor
???   ????????? database/db.go          # Conexi??n PostgreSQL con retry
???   ????????? handlers/               # Handlers HTTP
???   ???   ????????? auth.go             #   Registro / Login
???   ???   ????????? recursos.go         #   CRUD recursos
???   ???   ????????? reservas.go         #   CRUD reservas
???   ???   ????????? adjuntos.go         #   Upload/Download/Delete Ceph
???   ???   ????????? metrics.go          #   M??tricas Prometheus
???   ????????? middleware/             # Middleware
???   ???   ????????? auth.go             #   JWT validation
???   ???   ????????? metrics.go          #   Prometheus metrics
???   ????????? models/                 # Modelos GORM
???   ???   ????????? usuario.go
???   ???   ????????? recurso.go
???   ???   ????????? reserva.go
???   ???   ????????? adjunto.go
???   ????????? storage/
???       ????????? ceph.go             # Integraci??n con Ceph (rados CLI)
????????? start-lab.bat               # Inicio completo desde Windows
????????? startup.bat                 # Inicio r??pido desde Windows
????????? shutdown.bat                # Apagado desde Windows
????????? validate.bat                # Validaci??n desde Windows
????????? scripts/
???   ????????? incusinstall.sh         # Instalaci??n de Incus desde Zabbly
???   ????????? network.sh              # Configuraci??n OVN e infraestructura de red
???   ????????? profiles.sh             # Creaci??n de perfiles de recursos
???   ????????? volumes.sh              # Creaci??n de vol??menes persistentes
???   ????????? containers.sh           # Lanzamiento/configuraci??n de contenedores + proxy devices
???   ????????? setup-services.sh       # Instalaci??n de dependencias y ejecuci??n de Ansible
???   ????????? setup-lab.sh            # Orquestador principal (llama a los scripts de infra)
???   ????????? setup-db.sh             # Configuraci??n de PostgreSQL
???   ????????? setup-api-go.sh         # Configuraci??n de API Go + Gin (desde repo o inline)
???   ????????? setup-frontend.sh       # Frontend React + Vite
???   ????????? setup-metrics.sh        # M??tricas Prometheus + node_exporter
???   ????????? setup-grafana.sh        # Datasource y dashboards Grafana
???   ????????? setup-ceph.sh           # Cluster Ceph (MON+MGR+OSD+pool)
???   ????????? setup-ceph-client.sh    # Clientes Ceph en api/core
???   ????????? start-services.sh       # Arranque de servicios internos
???   ????????? validate.sh             # Validaci??n de infraestructura
???   ????????? validate-services.sh    # Validaci??n de servicios
???   ????????? shutdown.sh             # Apagado ordenado del laboratorio
???   ????????? startup.sh              # Arranque ordenado del laboratorio
```

---

## Red

| Par??metro | Valor |
|---|---|
| Tipo | OVN (Open Virtual Network) |
| Nombre | `lab-net` |
| Subred | `10.10.0.0/24` |
| NAT | Deshabilitado |
| Rango DHCP/OVN | `10.10.0.2 ??? 10.10.0.250` |

---

## Perfiles de recursos

| Perfil | CPUs | RAM | Rol |
|---|---|---|---|
| ctl | 1 | 512 MiB | Orquestaci??n |
| api | 2 | 1024 MiB | REST API |
| core | 2 | 1536 MiB | Frontend |
| db | 4 | 4096 MiB | PostgreSQL |
| mon | 2 | 1024 MiB | Prometheus + Grafana |
| ceph | 2 | 2048 MiB | Almacenamiento distribuido |

---

## Vol??menes persistentes

| Volumen | Montado en | Contenedor |
|---|---|---|
| `postgres-data` | `/var/lib/postgresql` | db |
| `prometheus-data` | `/prometheus` | mon |
| `grafana-data` | `/var/lib/grafana` | mon |
| `ceph-data` | `/var/lib/ceph` | ceph |
| `app-data` | `/app/data` | api, core |

---

## Configuraci??n de Servicios (Ansible)

A diferencia de la gesti??n manual, todo el provisionamiento de software dentro de los contenedores est?? automatizado a trav??s de Ansible.

El script `scripts/setup-services.sh` se encarga de:

1. Instalar Ansible en el host y la colecci??n de Incus (`community.general`).
2. Instalar Python3 en todos los contenedores.
3. Generar din??micamente un archivo de inventario `inventory.ini`.
4. Crear y ejecutar los Playbooks (`playbook-base.yml`, `playbook-db.yml`, `playbook-mon.yml`, `playbook-app.yml`).

Si en el futuro deseas re-ejecutar un aprovisionamiento o alterar una configuraci??n, solo debes editar y ejecutar este script.

---

## API REST (Go + Gin)

La API est?? escrita en Go usando el framework **Gin** con **GORM** para la base de datos. Se ejecuta como servicio `systemd` dentro del contenedor `api`.

### Autenticaci??n

| M??todo | Ruta | Descripci??n |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Registrar usuario (`email`, `password`) |
| `POST` | `/api/v1/auth/login` | Iniciar sesi??n, devuelve JWT |

### Recursos

| M??todo | Ruta | Auth | Descripci??n |
|---|---|---|---|
| `GET` | `/api/v1/recursos` | No | Listar todos los recursos |
| `GET` | `/api/v1/recursos/:id` | No | Obtener recurso por ID |
| `POST` | `/api/v1/recursos` | JWT | Crear recurso |
| `PUT` | `/api/v1/recursos/:id` | JWT | Actualizar recurso |
| `DELETE` | `/api/v1/recursos/:id` | JWT | Eliminar recurso |

### Reservas

| M??todo | Ruta | Auth | Descripci??n |
|---|---|---|---|
| `GET` | `/api/v1/reservas` | JWT | Listar reservas del usuario autenticado |
| `GET` | `/api/v1/reservas/:id` | JWT | Obtener reserva por ID |
| `POST` | `/api/v1/reservas` | JWT | Crear reserva |
| `PUT` | `/api/v1/reservas/:id` | JWT | Actualizar reserva |
| `DELETE` | `/api/v1/reservas/:id` | JWT | Cancelar reserva |

> `POST /api/v1/reservas` requiere: `{"id_recurso": 1, "fecha_inicio": "2026-06-01T10:00:00Z", "fecha_fin": "2026-06-01T12:00:00Z"}`. `id_usuario` se obtiene del JWT.

### Adjuntos (Ceph Storage)

| M??todo | Ruta | Auth | Descripci??n |
|---|---|---|---|
| `POST` | `/api/v1/adjuntos/upload` | JWT | Subir archivo a Ceph (multipart form, campo `file`, campo `id_reserva`) |
| `GET` | `/api/v1/adjuntos/:oid` | JWT | Descargar archivo desde Ceph |
| `DELETE` | `/api/v1/adjuntos/:oid` | JWT | Eliminar archivo de Ceph |

> Los archivos se almacenan en el pool `reservas-pool` de Ceph con OID `reserva_{id}_{timestamp}.ext`.

### Health

| M??todo | Ruta | Descripci??n |
|---|---|---|
| `GET` | `/api/v1/health` | Health check (DB + estado del servicio) |

### M??tricas

| M??todo | Ruta | Descripci??n |
|---|---|---|
| `GET` | `/metrics` | M??tricas Prometheus (requests totales, duraci??n, errores por endpoint) |

---

## Proxy devices (acceso desde el host)

Incus proxy devices permiten mapear puertos del contenedor al host. Se crean autom??ticamente con `scripts/containers.sh`:

```text
core:5173  ??? localhost:5173  (Frontend)
api:8080   ??? localhost:8080  (API REST)
mon:9090   ??? localhost:9090  (Prometheus)
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
- Distribuci??n **Debian** (o compatible) con Incus instalado
- PowerShell (administrador)

### Scripts disponibles

| Script | Descripci??n |
|---|---|
| `start-lab.bat` | Inicio completo: verifica WSL, arranca Incus + contenedores, crea proxy devices, espera puertos (5173, 8080, 9090), abre el navegador |
| `startup.bat` | Inicio r??pido: solo arranca contenedores + proxy devices |
| `shutdown.bat` | Apagado ordenado de todos los contenedores |
| `validate.bat` | Validaci??n: verifica WSL, estado de Incus y conectividad HTTP a los 3 servicios |

> Ejecutar como **Administrador** para acceso al socket de Incus y proxy devices.

### Uso t??pico

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

### Conexi??n app ??? base de datos (??? resuelto con setup-db.sh + setup-api-go.sh)
- [x] Crear usuario y base de datos en PostgreSQL (`reservas_db`, usuario `reservas_user`)
- [x] API Go + Gin con GORM conectada a PostgreSQL
- [x] Variables de entorno de conexi??n configuradas

### Servicios systemd (??? resuelto con setup-api-go.sh + setup-frontend.sh)
- [x] Unit file para API Go (`reservas-api.service`)
- [x] Unit file para frontend React (`reservas-frontend.service`)

### Observabilidad (??? resuelto con setup-metrics.sh + setup-grafana.sh)
- [x] Scraping Prometheus hacia `api`, `db`, `core`
- [x] Dashboards Grafana: Sistema y API Reservas
- [x] Datasource Prometheus en Grafana

### Almacenamiento (??? resuelto con setup-ceph.sh + setup-ceph-client.sh + api/storage/ceph.go)
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

## Operaci??n del laboratorio

### Arranque Completo

```bash
sudo bash scripts/startup.sh
```

El script inicia los contenedores garantizando dependencias: `ceph` (storage) ??? `db` ??? `mon` ??? `core` ??? `api` ??? `ctl`.

### Apagado Ordenado

```bash
sudo bash scripts/shutdown.sh
```

Detiene servicios permitiendo la bajada a disco y evitando corrupci??n: `api` ??? `core` ??? `mon` ??? `db` ??? `ceph` ??? `ctl`.

---

## Documentaci??n de referencia

| Archivo | Contenido |
|---|---|
| `infraestructura.md` | Justificaci??n t??cnica de Debian 13, matriz de decisi??n, y detalles minuciosos del funcionamiento de cada Script. (Documento Base) |
| `choices.md` | Log de todos los cambios con fecha, archivos afectados y raz??n |

---

*Proyecto acad??mico ??? Plataforma de Gesti??n de Reservas ??? Junio 2026*
