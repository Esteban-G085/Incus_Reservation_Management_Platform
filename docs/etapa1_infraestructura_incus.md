# Etapa 1 — Infraestructura Base con Incus
**Proyecto:** Plataforma de Gestión de Reservas sobre Incus  
**Fecha:** Mayo 2026  
**Entorno:** Windows 11 + WSL2 + Ubuntu 24.04  

---

## Contexto

El enunciado del proyecto asume un host Linux físico con Debian 13. Al no tener una máquina Linux dedicada, se optó por usar **WSL2 (Windows Subsystem for Linux)** como capa de compatibilidad, corriendo Ubuntu 24.04 como host de Incus. Los contenedores internos usan **Debian 13** tal como indica el documento de decisión técnica.

---

## Arquitectura Final

| Nodo | IP | CPUs | RAM | Disco |
|---|---|---|---|---|
| node-control | 10.10.0.2 | 1 | 256MiB | 4GiB |
| app-api | 10.10.0.3 | 1 | 768MiB | 8GiB |
| app-core | 10.10.0.4 | 1 | 768MiB | 8GiB |
| db-postgres | 10.10.0.5 | 2 | 2GiB | 20GiB |
| monitoring | 10.10.0.6 | 2 | 1.5GiB | 10GiB |
| ceph-node | 10.10.0.7 | 1 | 512MiB | 15GiB |

Red: OVN `lab-net` — `10.10.0.0/24`  
Storage: pool `default` tipo `dir`

---

## Paso 1 — Instalación de WSL2 e Incus

### 1.1 Instalar WSL2
Desde PowerShell como administrador:
```powershell
wsl --install
```
Reiniciar el equipo. Abrir Ubuntu desde el menú inicio y crear usuario y contraseña.

### 1.2 Configurar el kernel para Incus
Crear el archivo `C:\Users\TuUsuario\.wslconfig`:
```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
nestedVirtualization = true
```

### 1.3 Instalar Incus
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y incus
sudo incus admin init --minimal
sudo usermod -aG incus $USER
newgrp incus
```

### 1.4 Verificar instalación
```bash
incus version
# Client version: 6.0.0
# Server version: 6.0.0
```

---

## Paso 2 — Configurar permisos del proyecto

### Problema encontrado
Al intentar crear la red aparecía:
```
Error: Network not allowed in project
Error: User does not have permission for project "default"
```

### Solución
```bash
sudo incus project set default features.networks=true
```
A partir de aquí todos los comandos de Incus se ejecutan con `sudo`.

---

## Paso 3 — Crear Storage Pool

```bash
sudo incus storage create default dir
```

Verificar:
```bash
sudo incus storage list
# | default | dir | /var/lib/incus/storage-pools/default | | 2 | CREATED |
```

---

## Paso 4 — Instalar y configurar OVN

### 4.1 Verificar systemd
```bash
systemctl --version
# systemd 255
```

### 4.2 Instalar paquetes OVN
```bash
sudo apt install -y ovn-host ovn-central
```

### 4.3 Habilitar servicios Open vSwitch
```bash
sudo systemctl enable --now ovn-central ovn-host
```

### Problema encontrado
`ovn-central` y `ovn-host` aparecían como `active (exited)` en vez de `active (running)`. Esto es normal, son wrappers. Lo importante es que Open vSwitch esté corriendo:
```bash
sudo systemctl status ovsdb-server ovs-vswitchd --no-pager
# active (running) ✅
```

### 4.4 Iniciar OVN manualmente
El binario `ovn-ctl` no estaba en el PATH. Se encontró con:
```bash
find /usr -name "ovn-ctl" 2>/dev/null
# /usr/share/ovn/scripts/ovn-ctl
```

Iniciar northd y controller:
```bash
sudo /usr/share/ovn/scripts/ovn-ctl start_northd
sudo /usr/share/ovn/scripts/ovn-ctl start_controller
```

### 4.5 Conectar OVS con OVN
```bash
sudo ovs-vsctl set open_vswitch . \
  external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock \
  external-ids:ovn-encap-type=geneve \
  external-ids:ovn-encap-ip=127.0.0.1
```

### 4.6 Conectar Incus con OVN
```bash
sudo incus config set network.ovn.northbound_connection unix:/var/run/ovn/ovnnb_db.sock
```

### 4.7 Verificar
```bash
sudo /usr/share/ovn/scripts/ovn-ctl status_northd
# ovn-northd is running with pid XXXX

sudo /usr/share/ovn/scripts/ovn-ctl status_controller
# ovn-controller is running with pid XXXX
```

---

## Paso 5 — Crear la red OVN

OVN requiere un bridge como uplink antes de crear la red virtual.

### Problema encontrado al crear el bridge
Varios errores encadenados durante la creación:

**Error 1:**
```
Error: Option "network" is required
```
Solución: crear primero un bridge uplink.

**Error 2:**
```
Error: Missing required "ipv4.ovn.ranges" config key on uplink network
```
Solución: agregar `ipv4.ovn.ranges`.

**Error 3:**
```
Error: "ipv4.ovn.ranges" must be used in conjunction with non-overlapping "ipv4.dhcp.ranges"
```
Solución: definir rangos separados para DHCP y OVN.

**Error 4:**
```
Error: IP range "10.10.0.10-10.10.0.50" does not fall within any of the allowed networks [10.63.60.0/24]
```
El bridge tomó una IP diferente. Solución: corregir la IP del bridge primero.

### Secuencia correcta

```bash
# Crear bridge uplink
sudo incus network create incusbr0 \
  --type=bridge \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true

# Corregir IP si quedó diferente
sudo incus network set incusbr0 ipv4.address=10.10.0.1/24

# Agregar rangos sin solapamiento
sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=10.10.0.100-10.10.0.200 \
  ipv4.ovn.ranges=10.10.0.10-10.10.0.50

# Crear red OVN
sudo incus network create lab-net \
  --type=ovn \
  network=incusbr0 \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true
# Network lab-net created ✅
```

---

## Paso 6 — Crear perfiles de recursos

Los perfiles se ajustaron a los recursos reales del equipo:
- Host: 12 CPUs, 7.4GiB RAM disponibles
- Límite objetivo: no superar 6.2GiB entre todos los contenedores

```bash
sudo incus profile create node-control
sudo incus profile set node-control limits.cpu=1 limits.memory=256MiB

sudo incus profile create app-api
sudo incus profile set app-api limits.cpu=1 limits.memory=768MiB

sudo incus profile create app-core
sudo incus profile set app-core limits.cpu=1 limits.memory=768MiB

sudo incus profile create db-postgres
sudo incus profile set db-postgres limits.cpu=2 limits.memory=2GiB

sudo incus profile create monitoring
sudo incus profile set monitoring limits.cpu=2 limits.memory=1536MiB

sudo incus profile create ceph-node
sudo incus profile set ceph-node limits.cpu=1 limits.memory=512MiB
```

**Total RAM asignada: ~5.75GiB** — margen de ~450MiB libre.

---

## Paso 7 — Asignar disco a cada perfil

### Problema encontrado
Al intentar lanzar contenedores aparecía:
```
Error: Failed detecting root disk device: No root device could be found
```

El perfil `default` tenía disco pero los perfiles personalizados no. Se decidió asignar disco con tamaño explícito a cada perfil para evitar competencia por recursos en el orquestador.

### Solución

```bash
sudo incus profile device add node-control root disk path=/ pool=default size=4GiB
sudo incus profile device add app-api root disk path=/ pool=default size=8GiB
sudo incus profile device add app-core root disk path=/ pool=default size=8GiB
sudo incus profile device add db-postgres root disk path=/ pool=default size=20GiB
sudo incus profile device add monitoring root disk path=/ pool=default size=10GiB
sudo incus profile device add ceph-node root disk path=/ pool=default size=15GiB
```

**Total disco asignado: 65GiB** — disponible en host: 953GiB ✅

---

## Paso 8 — Crear volúmenes persistentes

```bash
sudo incus storage volume create default postgres-data
sudo incus storage volume create default prometheus-data
sudo incus storage volume create default grafana-data
sudo incus storage volume create default ceph-data
sudo incus storage volume create default app-data
```

---

## Paso 9 — Lanzar los contenedores

```bash
sudo incus launch images:debian/13 node-control -p node-control --network lab-net
sudo incus launch images:debian/13 app-api -p app-api --network lab-net
sudo incus launch images:debian/13 app-core -p app-core --network lab-net
sudo incus launch images:debian/13 db-postgres -p db-postgres --network lab-net
sudo incus launch images:debian/13 monitoring -p monitoring --network lab-net
sudo incus launch images:debian/13 ceph-node -p ceph-node --network lab-net
```

---

## Paso 10 — Verificar estado y conectividad

### Estado de contenedores
```bash
sudo incus list
```
Los 6 nodos deben aparecer como `RUNNING` con IPs en `10.10.0.0/24`.

### Prueba de conectividad
```bash
sudo incus exec node-control -- ping -c 2 10.10.0.3
sudo incus exec node-control -- ping -c 2 10.10.0.5
# 0% packet loss ✅
```

---

## Resumen de problemas y soluciones

| # | Error | Causa | Solución |
|---|---|---|---|
| 1 | `Network not allowed in project` | Proyecto default con restricciones | `sudo incus project set default features.networks=true` |
| 2 | `User does not have permission` | Usuario no en grupo incus | Usar `sudo` en todos los comandos Incus |
| 3 | `ovn-ctl: command not found` | Binario no estaba en el PATH | Usar ruta completa `/usr/share/ovn/scripts/ovn-ctl` |
| 4 | `ovn-central active (exited)` | Comportamiento normal del wrapper | Verificar `ovsdb-server` y `ovs-vswitchd` en su lugar |
| 5 | `Option "network" is required` | OVN necesita bridge uplink | Crear `incusbr0` primero como uplink |
| 6 | `Missing ipv4.ovn.ranges` | Bridge sin rango para OVN | Agregar `ipv4.ovn.ranges` y `ipv4.dhcp.ranges` separados |
| 7 | `IP range does not fall within allowed networks` | Bridge tomó IP diferente | Corregir con `incus network set incusbr0 ipv4.address=10.10.0.1/24` |
| 8 | `No root device could be found` | Perfiles sin disco asignado | Agregar dispositivo root con tamaño explícito a cada perfil |

---

## Checklist Etapa 1

- [x] WSL2 instalado y configurado
- [x] Incus 6.0.0 instalado y operativo
- [x] OVN + Open vSwitch configurados
- [x] Storage pool `default` creado
- [x] 6 perfiles con límites de CPU, RAM y disco
- [x] 5 volúmenes persistentes creados
- [x] Red OVN `lab-net` en `10.10.0.0/24`
- [x] 6 contenedores Debian 13 corriendo
- [x] Conectividad entre nodos verificada (0% packet loss)

---

## Próximos pasos — Etapa 2 (14–22 mayo)

- Instalar OpenTofu en `node-control`
- Convertir la infraestructura en archivos `.tf`
- Escribir playbooks Ansible para configurar cada nodo
- Automatizar el despliegue completo desde cero
