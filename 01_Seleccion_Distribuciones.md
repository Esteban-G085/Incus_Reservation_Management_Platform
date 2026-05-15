# Selección de Distribuciones Linux para la Plataforma de Gestión de Reservas sobre Incus

**Fecha:** Mayo 2026  
**Proyecto:** Plataforma de Gestión de Reservas - Laboratorio Académico sobre Incus  
**Versión:** Con implementación real (Etapa 1 completada)  

---

## 0. Stack Tecnológico

Una vista rápida de todas las piezas que componen el entorno de laboratorio:

| Capa | Tecnología | Rol |
|------|-----------|-----|
| **Sistema base** | Windows 11 + WSL2 | Host real donde corre el laboratorio |
| **Host de contenedores** | Ubuntu 24.04 (WSL2) | Corre Incus y gestiona los nodos |
| **Hipervisor de contenedores** | Incus 6.0.0 | Orquesta los 6 contenedores del proyecto |
| **Sistema operativo de nodos** | Debian 13 (trixie) | Imagen base de todos los contenedores |
| **Red virtual** | OVN + Open vSwitch | Red SDN (`lab-net`) entre contenedores |
| **Storage pool** | Incus dir pool | Volúmenes persistentes de datos |
| **Orquestación (próxima etapa)** | OpenTofu + Ansible | IaC y configuración automatizada |
| **Base de datos** | PostgreSQL | Persistencia de usuarios, recursos y reservas |
| **Observabilidad** | Prometheus + Grafana | Métricas y dashboards del clúster |
| **Almacenamiento distribuido** | Ceph | Volumen compartido entre nodos |

---

## 1. Contexto y Requisitos

### Hardware Real del Host (WSL2)

- **Procesador:** 12 CPUs (visibles desde WSL2)
- **Memoria RAM:** 7.4 GiB disponibles para contenedores
- **Almacenamiento:** 953 GiB libres en pool `default`
- **Kernel:** WSL2 con `cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1`

### Nodos Lógicos del Proyecto

| # | Nodo | Rol |
|---|------|-----|
| 1 | **node-control** | Orquestación y automatización (OpenTofu, Ansible) |
| 2 | **app-api** | Punto de entrada REST de la aplicación |
| 3 | **app-core** | Lógica de negocio y validaciones |
| 4 | **db-postgres** | Persistencia de datos (usuarios, recursos, reservas) |
| 5 | **monitoring** | Observabilidad (Prometheus + Grafana) |
| 6 | **ceph-node** | Almacenamiento distribuido |

### Criterios de Decisión

- **Estabilidad:** Sistema debe poder apagarse y reiniciarse sin fallos inesperados
- **Reproducibilidad:** Infraestructura como código, sin intervención manual
- **Recuperabilidad:** Datos persistentes incluso si un contenedor se destruye
- **Escala Didáctica:** Bajo consumo de recursos, funcionamiento en hardware modesto
- **Soporte a Largo Plazo:** LTS o versiones estables con garantía de 5+ años

---

## 2. Opciones Evaluadas y Descartadas

### Opción 1: Uniformidad con Ubuntu 22.04 LTS

**Distribución:** Ubuntu 22.04 LTS (jammy) en todos los nodos  
**Ventajas:**

- LTS con soporte hasta 2027
- Comunidad grande, documentación abundante
- Incus disponible en repos oficiales

**Desventajas:**

- ❌ Fricción de versiones entre host y contenedores
- ❌ Overhead innecesario en contenedores ligeros
- ❌ Debian 13 es más estable en entornos de servidor

---

### Opción 2: Especialización por Rol (Debian + Alpine + Ubuntu)

**Distribución:** Mezcla selectiva según nodo

- **node-control:** Debian 12 (herramientas CLI)
- **app-api, app-core:** Ubuntu 22.04 LTS
- **db-postgres:** Debian 12 slim
- **monitoring:** Ubuntu 22.04 LTS
- **ceph-node:** Alpine Linux 3.18

**Desventajas:**

- ❌ Múltiples sistemas de paquetes (apt, apk)
- ❌ Troubleshooting complejo (¿error de Alpine, Debian o Ubuntu?)
- ❌ Viola el principio "menos variables = más estable"
- ❌ Inviable en contexto académico con tiempo limitado

---

### Opción 3: Uniformidad Total con Ubuntu 22.04 LTS

**Distribución:** Ubuntu 22.04 LTS en host + todos los contenedores  

**Desventajas:**

- ❌ Requeriría cambiar el host WSL2 a Ubuntu 22.04 (regresión de versión)
- ❌ El host Ubuntu 24.04 ya funciona y tiene Incus operativo
- ❌ Cambio innecesario = riesgo innecesario

---

## 3. Decisión Final: Debian 13 en todos los contenedores

### Selección Implementada

| Nodo | Distribución | Versión | Imagen Incus | Estado |
|------|--------------|---------|--------------|--------|
| **Host WSL2** | Ubuntu | 24.04 | — (host) | ✅ Operativo |
| **node-control** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |
| **app-api** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |
| **app-core** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |
| **db-postgres** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |
| **monitoring** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |
| **ceph-node** | Debian 13 | trixie | `images:debian/13` | ✅ RUNNING |

### Ventajas Confirmadas en Implementación Real

✅ **Un solo ecosistema de paquetes** — `apt` en todos los nodos, sin ambigüedad de gestor  
✅ **Troubleshooting directo** — si algo falla, no es un problema de versión de libc  
✅ **Debian 13 lanza desde imágenes remotas de Incus sin configuración extra** — `images:debian/13` funciona out of the box  
✅ **Bajo consumo** — 6 contenedores Debian 13 caben en 5.75 GiB de RAM con margen  
✅ **Shutdown/startup predecibles** — conectividad confirmada con 0% packet loss entre nodos  

---

## 4. Configuración de Perfiles Incus

### Perfiles Implementados

```bash
# node-control — orquestación liviana
sudo incus profile create node-control
sudo incus profile set node-control limits.cpu=1 limits.memory=256MiB

# app-api — entrada REST, I/O bound
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

# ceph-node — almacenamiento distribuido
sudo incus profile create ceph-node
sudo incus profile set ceph-node limits.cpu=1 limits.memory=512MiB
```

### Asignación de Disco por Perfil

> Problema encontrado: los perfiles personalizados no heredan disco del perfil `default`. Se agregó dispositivo root explícito a cada uno.

```bash
sudo incus profile device add node-control  root disk path=/ pool=default size=4GiB
sudo incus profile device add app-api       root disk path=/ pool=default size=8GiB
sudo incus profile device add app-core      root disk path=/ pool=default size=8GiB
sudo incus profile device add db-postgres   root disk path=/ pool=default size=20GiB
sudo incus profile device add monitoring    root disk path=/ pool=default size=10GiB
sudo incus profile device add ceph-node     root disk path=/ pool=default size=15GiB
```

### Cálculo Real de Recursos

| Nodo | CPUs | RAM | Disco |
|------|------|-----|-------|
| node-control | 1 | 256 MiB | 4 GiB |
| app-api | 1 | 768 MiB | 8 GiB |
| app-core | 1 | 768 MiB | 8 GiB |
| db-postgres | 2 | 2 GiB | 20 GiB |
| monitoring | 2 | 1.5 GiB | 10 GiB |
| ceph-node | 1 | 512 MiB | 15 GiB |
| **TOTAL** | **8** | **~5.75 GiB** | **65 GiB** |
| **Disponible** | **12** | **7.4 GiB** | **953 GiB** |
| **Margen** | **4** | **~1.65 GiB** | **888 GiB** |

---

## 5. Configuración de Volúmenes Persistentes

**Regla de Oro:** Si elimino un contenedor, sus datos persisten en el volumen. Si reinicio WSL2, todos los volúmenes reaparecen y los contenedores los reclaman.

### Creación de Volúmenes (Implementada)

```bash
sudo incus storage volume create default postgres-data
sudo incus storage volume create default prometheus-data
sudo incus storage volume create default grafana-data
sudo incus storage volume create default ceph-data
sudo incus storage volume create default app-data
```

### Montaje de Volúmenes en Contenedores

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

# Aplicación compartida entre app-api y app-core
sudo incus config device add app-api  app-volume disk source=app-data path=/app/data
sudo incus config device add app-core app-volume disk source=app-data path=/app/data
```

---

## 6. Procedimiento de Reproducción (Actualizado)

### Paso 1: Configurar WSL2

En PowerShell como administrador:

```powershell
wsl --install
```

Crear `C:\Users\TuUsuario\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
nestedVirtualization = true
```

Reiniciar el equipo. Abrir Ubuntu y crear usuario.

### Paso 2: Instalar Incus

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

### Paso 3: Habilitar redes en el proyecto default

```bash
sudo incus project set default features.networks=true
```

### Paso 4: Crear Storage Pool

```bash
sudo incus storage create default dir
sudo incus storage list  # debe aparecer CREATED
```

### Paso 5: Instalar y configurar OVN

```bash
sudo apt install -y ovn-host ovn-central
sudo systemctl enable --now ovn-central ovn-host

# Iniciar OVN manualmente (binario no está en PATH)
sudo /usr/share/ovn/scripts/ovn-ctl start_northd
sudo /usr/share/ovn/scripts/ovn-ctl start_controller

# Conectar OVS con OVN
sudo ovs-vsctl set open_vswitch . \
  external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock \
  external-ids:ovn-encap-type=geneve \
  external-ids:ovn-encap-ip=127.0.0.1

# Conectar Incus con OVN
sudo incus config set network.ovn.northbound_connection unix:/var/run/ovn/ovnnb_db.sock
```

### Paso 6: Crear red OVN

```bash
# Crear bridge uplink primero (OVN lo requiere)
sudo incus network create incusbr0 \
  --type=bridge \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true

# Configurar rangos sin solapamiento
sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=10.10.0.100-10.10.0.200 \
  ipv4.ovn.ranges=10.10.0.10-10.10.0.50

# Crear red OVN final
sudo incus network create lab-net \
  --type=ovn \
  network=incusbr0 \
  ipv4.address=10.10.0.1/24 \
  ipv4.nat=true
# Network lab-net created ✅
```

### Paso 7: Crear perfiles y lanzar contenedores

```bash
# (ver sección 4 para comandos de perfiles)

# Lanzar todos los nodos
sudo incus launch images:debian/13 node-control -p node-control --network lab-net
sudo incus launch images:debian/13 app-api      -p app-api      --network lab-net
sudo incus launch images:debian/13 app-core     -p app-core     --network lab-net
sudo incus launch images:debian/13 db-postgres  -p db-postgres  --network lab-net
sudo incus launch images:debian/13 monitoring   -p monitoring   --network lab-net
sudo incus launch images:debian/13 ceph-node    -p ceph-node    --network lab-net
```

### Paso 8: Validar conectividad

```bash
sudo incus list
# Los 6 nodos deben aparecer RUNNING con IPs en 10.10.0.0/24

sudo incus exec node-control -- ping -c 2 10.10.0.3
sudo incus exec node-control -- ping -c 2 10.10.0.5
# 0% packet loss ✅
```

---

## 7. Procedimiento de Apagado y Reinicio Seguro

### Apagado Ordenado

```bash
#!/bin/bash
# shutdown-lab.sh

echo "=== APAGADO ORDENADO DEL LABORATORIO ==="

sudo incus stop app-api   2>/dev/null || echo "⚠️  app-api ya detenido"
sudo incus stop app-core  2>/dev/null || echo "⚠️  app-core ya detenido"
sleep 3

sudo incus stop monitoring 2>/dev/null || echo "⚠️  monitoring ya detenido"
sleep 2

sudo incus stop ceph-node  2>/dev/null || echo "⚠️  ceph-node ya detenido"
sleep 2

sudo incus stop db-postgres 2>/dev/null || echo "⚠️  db-postgres ya detenido"
sleep 5

sudo incus stop node-control 2>/dev/null || echo "⚠️  node-control ya detenido"

echo "✅ Apagado completado — es seguro cerrar WSL2"
sudo incus list
```

### Reinicio Ordenado

```bash
#!/bin/bash
# startup-lab.sh

echo "=== REINICIO DEL LABORATORIO ==="

# Levantar OVN primero (puede haberse detenido con WSL2)
sudo /usr/share/ovn/scripts/ovn-ctl start_northd
sudo /usr/share/ovn/scripts/ovn-ctl start_controller

sudo incus start ceph-node;    sleep 5
sudo incus start db-postgres;  sleep 10
sudo incus start monitoring;   sleep 5
sudo incus start app-core;     sleep 3
sudo incus start app-api;      sleep 3
sudo incus start node-control

echo "✅ Laboratorio operativo"
sudo incus list
```

---

## 8. Problemas Encontrados y Soluciones

| # | Error | Causa raíz | Solución aplicada |
|---|-------|-----------|-------------------|
| 1 | `Network not allowed in project` | Proyecto default con restricciones | `sudo incus project set default features.networks=true` |
| 2 | `User does not have permission` | Usuario no en grupo incus | Usar `sudo` en todos los comandos Incus |
| 3 | `ovn-ctl: command not found` | Binario no está en PATH | Ruta completa: `/usr/share/ovn/scripts/ovn-ctl` |
| 4 | `ovn-central active (exited)` | Comportamiento normal del wrapper | Verificar `ovsdb-server` y `ovs-vswitchd` en su lugar |
| 5 | `Option "network" is required` | OVN necesita bridge uplink | Crear `incusbr0` como bridge antes de la red OVN |
| 6 | `Missing ipv4.ovn.ranges` | Bridge sin rango para OVN | Agregar `ipv4.ovn.ranges` y `ipv4.dhcp.ranges` separados |
| 7 | `IP range does not fall within allowed networks` | Bridge tomó IP distinta | `sudo incus network set incusbr0 ipv4.address=10.10.0.1/24` |
| 8 | `No root device could be found` | Perfiles sin disco asignado | Agregar dispositivo root con tamaño explícito a cada perfil |

---

## 9. Checklist de Implementación — Etapa 1

- [x] WSL2 instalado y configurado con cgroups v2
- [x] Incus 6.0.0 instalado y operativo
- [x] Permisos del proyecto default habilitados
- [x] Storage pool `default` tipo `dir` creado
- [x] OVN + Open vSwitch instalados y configurados manualmente
- [x] Bridge uplink `incusbr0` creado con rangos sin solapamiento
- [x] Red OVN `lab-net` (`10.10.0.0/24`) creada
- [x] 6 perfiles con límites de CPU, RAM y disco asignados
- [x] 5 volúmenes persistentes creados
- [x] 6 contenedores Debian 13 corriendo (`RUNNING`)
- [x] Conectividad entre nodos verificada (0% packet loss)

---

**Decisión Final:** Debian 13 en todos los contenedores — confirmada tras implementación real.

## 10. Referencias

- [Incus Documentation](https://linuxcontainers.org/incus/)
- [Debian 13 Release Notes](https://www.debian.org/releases/trixie/)
- [OpenTofu Provider for Incus](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Prometheus Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [PostgreSQL Administration](https://www.postgresql.org/docs/15/admin.html)
- [OVN Architecture](https://www.ovn.org/en/architecture/)
- [WSL2 Kernel Configuration](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)

---

**Documento de Decisión Técnica v2.0 — Proyecto Incus 2026**  
*Actualizado con implementación real — Etapa 1 completada el 14 de mayo de 2026*  
*Estabilidad por Simplicidad y Uniformidad*
