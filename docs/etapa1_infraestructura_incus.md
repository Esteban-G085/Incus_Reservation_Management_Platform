# Etapa 1 — Infraestructura Base con Incus

**Proyecto:** Plataforma de Gestión de Reservas sobre Incus  
**Fecha:** Mayo 2026  
**Entorno:** Windows 11 + WSL2 + Ubuntu 24.04  
**Versión del documento:** 2.0 (mejorada tras implementación real)

---

## 0. Stack Tecnológico Completo

| Capa | Tecnología | Rol |
|------|-----------|-----|
| **Sistema base** | Windows 11 + WSL2 | Host real del laboratorio |
| **Host de contenedores** | Ubuntu 24.04 (WSL2) | Corre Incus y gestiona los nodos |
| **Hipervisor** | Incus 6.0.0 | Orquesta 6 contenedores |
| **OS de nodos** | Debian 13 (trixie) | Imagen base uniforme |
| **Red virtual** | OVN + Open vSwitch | Red SDN `lab-net` entre contenedores |
| **Storage pool** | Incus `dir` pool | Volúmenes persistentes |
| **IaC** | OpenTofu *(Etapa 2)* | Infraestructura como código |
| **Configuración** | Ansible *(Etapa 2)* | Configuración automatizada |
| **Base de datos** | PostgreSQL 15 *(Etapa 3)* | Persistencia de reservas |
| **Observabilidad** | Prometheus + Grafana *(Etapa 3)* | Métricas y dashboards |
| **Almacenamiento** | Ceph *(Etapa 3)* | Volumen compartido |

---

## 1. Contexto y Decisión de Plataforma

### 1.1 Hardware Real del Host

```
Procesador:     12 CPUs (visibles desde WSL2)
Memoria RAM:    7.4 GiB disponibles para contenedores
Almacenamiento: 953 GiB libres en pool default
Kernel:         WSL2 con cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
```

### 1.2 Por qué WSL2 en lugar de Linux físico

El enunciado original asume un host Linux dedicado con Debian 13. Al no disponer de hardware físico dedicado, se optó por **WSL2** como capa de compatibilidad. Esto demuestra que el stack completo es **reproducible en hardware de desarrollo cotidiano**.

**Ventajas confirmadas:**

- Reproducibilidad total en cualquier PC Windows 11
- Snapshots del sistema WSL2 para backup completo (`wsl --export`)
- Kernel Linux actualizado sin depender de BIOS/UEFI físico
- Integración nativa con filesystem Windows

**Limitaciones documentadas:**

- OVN northd/controller pueden detenerse al reiniciar WSL2 (requiere `start-lab.sh`)
- Contenedores con red OVN pierden conectividad a Internet (documentado en Etapa 2)
- `systemd` en WSL2 tiene comportamientos ligeramente diferentes a bare-metal

---

## 2. Arquitectura Final

```
Windows 11
└── WSL2
    └── Ubuntu 24.04  (host Incus)
        └── Red OVN: lab-net (10.10.0.0/24)
            ├── node-control   10.10.0.2  — OpenTofu · Ansible · SSH
            ├── app-api        10.10.0.3  — API REST
            ├── app-core       10.10.0.4  — Lógica de negocio
            ├── db-postgres    10.10.0.5  — PostgreSQL
            ├── monitoring     10.10.0.6  — Prometheus · Grafana
            └── ceph-node      10.10.0.7  — Almacenamiento distribuido
```

### 2.1 Recursos por Nodo

| Nodo | CPUs | RAM | Disco | Rol |
|------|:----:|:---:|:-----:|-----|
| node-control | 1 | 256 MiB | 4 GiB | Orquestación |
| app-api | 1 | 768 MiB | 8 GiB | Punto de entrada REST |
| app-core | 1 | 768 MiB | 8 GiB | Lógica de negocio |
| db-postgres | 2 | 2 GiB | 20 GiB | Base de datos |
| monitoring | 2 | 1.5 GiB | 10 GiB | Observabilidad |
| ceph-node | 1 | 512 MiB | 15 GiB | Almacenamiento |
| **Total** | **8** | **~5.75 GiB** | **65 GiB** | |
| **Disponible** | **12** | **7.4 GiB** | **953 GiB** | |
| **Margen** | **4** | **~1.65 GiB** | **888 GiB** | |

---

## 3. Procedimiento de Instalación Completo

### 3.1 WSL2 — Configuración Inicial

```powershell
# PowerShell como Administrador
wsl --install
```

Reiniciar el equipo. Abrir Ubuntu desde el menú inicio y crear usuario/contraseña.

Crear `C:\Users\TuUsuario\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
nestedVirtualization = true
```

**Reiniciar el equipo.** Esto habilita cgroups v2, requisito para Incus.

### 3.2 Incus — Instalación

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y incus
sudo incus admin init --minimal
sudo usermod -aG incus $USER
newgrp incus
```

Verificar:

```bash
incus version
# Client version: 6.0.0
# Server version: 6.0.0
```

### 3.3 Permisos del Proyecto

```bash
sudo incus project set default features.networks=true
```

**Por qué:** El proyecto `default` tiene restricciones por defecto que impiden crear redes. Sin este paso, `incus network create` falla con `Network not allowed in project`.

### 3.4 Storage Pool

```bash
sudo incus storage create default dir
sudo incus storage list
# | default | dir | /var/lib/incus/storage-pools/default | | 2 | CREATED |
```

### 3.5 OVN + Open vSwitch

#### 3.5.1 Instalación

```bash
sudo apt install -y ovn-host ovn-central
sudo systemctl enable --now ovn-central ovn-host
```

**Nota importante:** `ovn-central` y `ovn-host` aparecen como `active (exited)`. Esto es **normal** — son wrappers. Lo crítico es que Open vSwitch esté corriendo:

```bash
sudo systemctl status ovsdb-server ovs-vswitchd --no-pager
# active (running)
```

#### 3.5.2 Iniciar OVN manualmente

El binario `ovn-ctl` **no está en el PATH** por defecto. Se encuentra en:

```bash
find /usr -name "ovn-ctl" 2>/dev/null
# /usr/share/ovn/scripts/ovn-ctl
```

Iniciar servicios:

```bash
sudo /usr/share/ovn/scripts/ovn-ctl start_northd
sudo /usr/share/ovn/scripts/ovn-ctl start_controller
```

Verificar:

```bash
sudo /usr/share/ovn/scripts/ovn-ctl status_northd
# ovn-northd is running with pid XXXX

sudo /usr/share/ovn/scripts/ovn-ctl status_controller
# ovn-controller is running with pid XXXX
```

#### 3.5.3 Conectar OVS con OVN

```bash
sudo ovs-vsctl set open_vswitch . \
  external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock \
  external-ids:ovn-encap-type=geneve \
  external-ids:ovn-encap-ip=127.0.0.1
```

#### 3.5.4 Conectar Incus con OVN

```bash
sudo incus config set network.ovn.northbound_connection unix:/var/run/ovn/ovnnb_db.sock
```

---

## 4. Red OVN — Creación paso a paso

OVN requiere un **bridge uplink** antes de crear la red virtual.

### 4.1 Errores encontrados y secuencia correcta

| Error | Causa | Solución |
|-------|-------|----------|
| `Option "network" is required` | OVN necesita bridge uplink | Crear `incusbr0` primero |
| `Missing required "ipv4.ovn.ranges"` | Bridge sin rango para OVN | Agregar `ipv4.ovn.ranges` |
| `"ipv4.ovn.ranges" must be used with non-overlapping "ipv4.dhcp.ranges"` | Rangos solapados | Definir rangos separados |
| `IP range does not fall within allowed networks` | Bridge tomó IP diferente | Corregir IP del bridge |

### 4.2 Secuencia correcta

```bash
# 1. Crear bridge uplink
sudo incus network create incusbr0 \
  --type=bridge \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true

# 2. Corregir IP si quedó diferente
sudo incus network set incusbr0 ipv4.address=10.10.0.1/24

# 3. Agregar rangos sin solapamiento
sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=10.10.0.100-10.10.0.200 \
  ipv4.ovn.ranges=10.10.0.10-10.10.0.50

# 4. Crear red OVN final
sudo incus network create lab-net \
  --type=ovn \
  network=incusbr0 \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true
# Network lab-net created
```

---

## 5. Perfiles de Recursos

### 5.1 Creación

```bash
# node-control — orquestación liviana
sudo incus profile create node-control
sudo incus profile set node-control limits.cpu=1 limits.memory=256MiB

# app-api — entrada REST
sudo incus profile create app-api
sudo incus profile set app-api limits.cpu=1 limits.memory=768MiB

# app-core — lógica de negocio
sudo incus profile create app-core
sudo incus profile set app-core limits.cpu=1 limits.memory=768MiB

# db-postgres — crítico, prioridad de recursos
sudo incus profile create db-postgres
sudo incus profile set db-postgres limits.cpu=2 limits.memory=2GiB

# monitoring — recolección de métricas
sudo incus profile create monitoring
sudo incus profile set monitoring limits.cpu=2 limits.memory=1536MiB

# ceph-node — almacenamiento
sudo incus profile create ceph-node
sudo incus profile set ceph-node limits.cpu=1 limits.memory=512MiB
```

### 5.2 Problema: disco no heredado

**Error:** `No root device could be found`

**Causa:** Los perfiles personalizados no heredan el dispositivo `root` del perfil `default`.

**Solución:** Agregar disco explícito a cada perfil:

```bash
sudo incus profile device add node-control  root disk path=/ pool=default size=4GiB
sudo incus profile device add app-api       root disk path=/ pool=default size=8GiB
sudo incus profile device add app-core    root disk path=/ pool=default size=8GiB
sudo incus profile device add db-postgres root disk path=/ pool=default size=20GiB
sudo incus profile device add monitoring  root disk path=/ pool=default size=10GiB
sudo incus profile device add ceph-node   root disk path=/ pool=default size=15GiB
```

---

## 6. Volúmenes Persistentes

**Regla de Oro:** Si elimino un contenedor, sus datos persisten en el volumen. Si reinicio WSL2, todos los volúmenes reaparecen.

```bash
sudo incus storage volume create default postgres-data
sudo incus storage volume create default prometheus-data
sudo incus storage volume create default grafana-data
sudo incus storage volume create default ceph-data
sudo incus storage volume create default app-data
```

### 6.1 Montaje en contenedores (para Etapa 3)

```bash
# PostgreSQL
sudo incus config device add db-postgres postgres-volume disk \
  source=postgres-data path=/var/lib/postgresql

# Prometheus
sudo incus config device add monitoring prometheus-volume disk \
  source=prometheus-data path=/prometheus

# Grafana
sudo incus config device add monitoring grafana-volume disk \
  source=grafana-data path=/var/lib/grafana

# Ceph
sudo incus config device add ceph-node ceph-volume disk \
  source=ceph-data path=/var/lib/ceph

# Aplicación compartida
sudo incus config device add app-api  app-volume disk source=app-data path=/app/data
sudo incus config device add app-core app-volume disk source=app-data path=/app/data
```

---

## 7. Lanzar Contenedores

```bash
sudo incus launch images:debian/13 node-control -p node-control --network lab-net
sudo incus launch images:debian/13 app-api      -p app-api      --network lab-net
sudo incus launch images:debian/13 app-core     -p app-core     --network lab-net
sudo incus launch images:debian/13 db-postgres  -p db-postgres  --network lab-net
sudo incus launch images:debian/13 monitoring   -p monitoring   --network lab-net
sudo incus launch images:debian/13 ceph-node    -p ceph-node    --network lab-net
```

Esperar 5 segundos para que obtengan IP.

---

## 8. Verificación de Conectividad

```bash
sudo incus list
# Los 6 nodos deben aparecer RUNNING con IPs en 10.10.0.0/24

sudo incus exec node-control -- ping -c 2 10.10.0.3
sudo incus exec node-control -- ping -c 2 10.10.0.5
# 0% packet loss
```

---

## 9. Scripts de Automatización

### 9.1 setup-lab.sh (creación completa)

Script con limpieza automática en caso de fallo (`trap cleanup ERR`), verificaciones previas de OVN, y secuencia ordenada: pool → bridge → red → perfiles → volúmenes → contenedores → verificación.

**Características:**

- Colores en terminal para diferenciar INFO/OK/WARN/ERROR
- Limpieza completa si algo falla (elimina contenedores, redes, perfiles, volúmenes)
- Verificación de conectividad final con ping desde `node-control`

### 9.2 start-lab.sh (arranque)

Secuencia: iniciar OVN (northd + controller) → iniciar contenedores → esperar IPs → verificar conectividad.

**Importante:** OVN se detiene cuando WSL2 se apaga. Este script debe ejecutarse siempre después de reiniciar WSL2.

### 9.3 stop-lab.sh (apagado limpio)

Secuencia: detener contenedores en orden inverso de dependencias → detener OVN controller → detener OVN northd.

---

## 10. Problemas Encontrados y Soluciones (Resumen)

| # | Error | Causa raíz | Solución |
|---|-------|-----------|----------|
| 1 | `Network not allowed in project` | Proyecto default con restricciones | `sudo incus project set default features.networks=true` |
| 2 | `User does not have permission` | Usuario no en grupo incus | Usar `sudo` en todos los comandos Incus |
| 3 | `ovn-ctl: command not found` | Binario no está en PATH | Ruta completa: `/usr/share/ovn/scripts/ovn-ctl` |
| 4 | `ovn-central active (exited)` | Comportamiento normal del wrapper | Verificar `ovsdb-server` y `ovs-vswitchd` |
| 5 | `Option "network" is required` | OVN necesita bridge uplink | Crear `incusbr0` como bridge primero |
| 6 | `Missing ipv4.ovn.ranges` | Bridge sin rango para OVN | Agregar `ipv4.ovn.ranges` y `ipv4.dhcp.ranges` separados |
| 7 | `IP range does not fall within allowed networks` | Bridge tomó IP distinta | `sudo incus network set incusbr0 ipv4.address=10.10.0.1/24` |
| 8 | `No root device could be found` | Perfiles sin disco asignado | Agregar dispositivo root con tamaño explícito a cada perfil |
| 9 | Contenedores sin Internet | Gateway OVN no enruta a WAN | Documentado como limitación de red OVN en WSL2 |

---

## 11. Checklist de Implementación — Etapa 1

- [x] WSL2 instalado y configurado con cgroups v2
- [x] Incus 6.0.0 instalado y operativo
- [x] Permisos del proyecto default habilitados (`features.networks=true`)
- [x] Storage pool `default` tipo `dir` creado
- [x] OVN + Open vSwitch instalados y configurados manualmente
- [x] Bridge uplink `incusbr0` creado con rangos sin solapamiento
- [x] Red OVN `lab-net` (`10.10.0.0/24`) creada
- [x] 6 perfiles con límites de CPU, RAM y disco asignados
- [x] 5 volúmenes persistentes creados
- [x] 6 contenedores Debian 13 corriendo (`RUNNING`)
- [x] Conectividad entre nodos verificada (0% packet loss)
- [x] Scripts `setup-lab.sh`, `start-lab.sh`, `stop-lab.sh` creados y probados

---

## 12. Transición a Etapa 2

La infraestructura base está completa y estable. Los siguientes pasos están documentados en:

- `etapa2_iac_opentofu.md` — Infraestructura como Código con OpenTofu

**Puntos de entrada para IaC:**

- Storage pool `default` → `incus_storage_pool.default`
- 6 perfiles → `incus_profile.node[*]`
- 6 contenedores → `incus_instance.node[*]`
- Redes y volúmenes → infraestructura base existente (referenciada pero no recreada)

---

## 13. Referencias

- [Incus Documentation](https://linuxcontainers.org/incus/)
- [Debian 13 Release Notes](https://www.debian.org/releases/trixie/)
- [OpenTofu Provider for Incus](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [OVN Architecture](https://www.ovn.org/en/architecture/)
- [WSL2 Kernel Configuration](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)

---
