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
- [Pendiente](#pendiente)
- [Operación del laboratorio](#operación-del-laboratorio)
- [Documentación de referencia](#documentación-de-referencia)

---

## Arquitectura

```
Host: Debian 13 (Trixie) — WSL 2 sobre Windows 11 o Baremetal
       │
       └── Incus + OVN
              │
              └── lab-net (10.10.0.0/24, sin NAT)
                     │
          ┌──────────┼──────────────────────────────┐
          │          │          │          │         │         │
        [ctl]      [api]      [core]     [db]      [mon]    [ceph]
      .0.2/24    .0.3/24    .0.4/24   .0.5/24   .0.6/24  .0.7/24
   Orquestación  REST API   Lógica  PostgreSQL Prom+Graf  Storage
```

---

## Requisitos

| Componente | Mínimo recomendado |
|---|---|
| CPU | 4 cores |
| RAM | 8 GB (el lab usa ~1.1 GB en idle) |
| Almacenamiento | 20 GB SSD |
| OS Host | Debian 13 (Trixie) — físico o WSL 2 |

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

# 5. Validar el despliegue
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

### Servicios configurados con Ansible

| Contenedor | Servicio | Estado |
|---|---|---|
| ctl | Orquestación / Ansible base | ✅ |
| api | Entorno Python / FastAPI | ✅ |
| core | Entorno Python / FastAPI | ✅ |
| db | PostgreSQL 15 | ✅ (activo) |
| mon | Prometheus | ✅ (activo) |
| mon | Grafana | ✅ (activo) |
| ceph | Ceph Storage | 🔄 pendiente |

---

## Estructura del repositorio

```text
Incus_Reservation_Management_Platform/
├── README.md                   # Este archivo
├── choices.md                  # Log de cambios técnicos y estado del despliegue
├── infraestructura.md          # Documentación técnica y desglose de scripts
├── setupnetwork.md             # Guía de la estructura teórica OVN
├── scripts/
│   ├── incusinstall.sh         # Instalación de Incus desde Zabbly
│   ├── network.sh              # Configuración OVN e infraestructura de red
│   ├── profiles.sh             # Creación de perfiles de recursos
│   ├── volumes.sh              # Creación de volúmenes persistentes
│   ├── containers.sh           # Lanzamiento y configuración de contenedores
│   ├── setup-services.sh       # Instalación de dependencias y ejecución de Ansible
│   ├── setup-lab.sh            # Orquestador principal (llama a los scripts de infra)
│   ├── validate.sh             # Validación de contenedores y servicios
│   ├── shutdown.sh             # Apagado ordenado del laboratorio
│   └── startup.sh              # Arranque ordenado del laboratorio
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
| core | 2 | 1536 MiB | Lógica de negocio |
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

## Pendiente

### Siguiente prioridad — Conexión app → base de datos

- [ ] Crear usuario y base de datos en PostgreSQL (`reservas_db`, usuario `app`)
- [ ] Instalar `psycopg2` u ORMs en `api` y `core`
- [ ] Configurar variables de entorno de conexión en el proyecto FastAPI.

### Servicios systemd para la app

- [ ] Crear unit files para FastAPI en `api` y `core`
- [ ] Habilitar arranque automático del uvicorn con el contenedor.

### Observabilidad

- [ ] Configurar scraping de Prometheus hacia `api`, `core` y `db`
- [ ] Importar dashboards base en Grafana (PostgreSQL, sistema)
- [ ] Configurar data source Prometheus en Grafana

### Almacenamiento

- [ ] Configurar Ceph en `ceph` (MON + OSD mínimo)
- [ ] Integrar volumen Ceph con `api` y `core`

---

## Operación del laboratorio

### Arranque Completo

```bash
sudo bash scripts/startup.sh
```

El script inicia los contenedores garantizando dependencias: `ceph` → `db` → `mon` → `core` → `api` → `ctl`.

### Apagado Ordenado

```bash
sudo bash scripts/shutdown.sh
```

Detiene servicios permitiendo la bajada a disco y evitando corrupción: `api` → `core` → `mon` → `ceph` → `db` → `ctl`.

---

## Documentación de referencia

| Archivo | Contenido |
|---|---|
| `infraestructura.md` | Justificación técnica de Debian 13, matriz de decisión, y detalles minuciosos del funcionamiento de cada Script. (Documento Base) |
| `choices.md` | Log de todos los cambios con fecha, archivos afectados y razón |

---

*Proyecto académico — Plataforma de Gestión de Reservas — Mayo 2026*
