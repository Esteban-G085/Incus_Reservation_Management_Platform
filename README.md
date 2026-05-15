# 🖥️ Plataforma de Gestión de Reservas sobre Incus

> Laboratorio académico de infraestructura como código: 6 contenedores Debian 13 orquestados con Incus, OVN y automatizados con OpenTofu + Ansible.

![Estado](https://img.shields.io/badge/Etapa%201-Completada-brightgreen)
![Incus](https://img.shields.io/badge/Incus-6.0.0-blue)
![Debian](https://img.shields.io/badge/Contenedores-Debian%2013-red)
![Plataforma](https://img.shields.io/badge/Host-WSL2%20%2B%20Ubuntu%2024.04-orange)
![Licencia](https://img.shields.io/badge/Licencia-MIT-lightgrey)

---

## 📋 Descripción

Este proyecto implementa una **plataforma completa de gestión de reservas** (usuarios, recursos, disponibilidad) sobre un clúster de contenedores Incus. El objetivo académico es aprender infraestructura como código aplicando herramientas reales de la industria: Incus, OVN, OpenTofu y Ansible.

El entorno corre sobre **Windows 11 + WSL2 + Ubuntu 24.04** en lugar de un servidor Linux físico, lo que demuestra que el stack completo es reproducible en hardware de desarrollo cotidiano.

---

## 🏗️ Arquitectura

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

### Recursos por nodo

| Nodo | CPUs | RAM | Disco | IP |
|------|:----:|:---:|:-----:|-----|
| node-control | 1 | 256 MiB | 4 GiB | 10.10.0.2 |
| app-api | 1 | 768 MiB | 8 GiB | 10.10.0.3 |
| app-core | 1 | 768 MiB | 8 GiB | 10.10.0.4 |
| db-postgres | 2 | 2 GiB | 20 GiB | 10.10.0.5 |
| monitoring | 2 | 1.5 GiB | 10 GiB | 10.10.0.6 |
| ceph-node | 1 | 512 MiB | 15 GiB | 10.10.0.7 |
| **Total** | **8** | **~5.75 GiB** | **65 GiB** | — |

---

## 🔧 Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Sistema base | Windows 11 + WSL2 |
| Host de contenedores | Ubuntu 24.04 |
| Orquestador | Incus 6.0.0 |
| OS de nodos | Debian 13 (trixie) |
| Red virtual | OVN + Open vSwitch |
| Storage pool | Incus dir pool |
| IaC | OpenTofu *(Etapa 2)* |
| Configuración | Ansible *(Etapa 2)* |
| Base de datos | PostgreSQL 15 |
| Observabilidad | Prometheus + Grafana |
| Almacenamiento | Ceph |

---

## 📁 Estructura del Repositorio

```
.
├── docs/
│   ├── 01_Seleccion_Distribuciones_Linux.md   # Decisión técnica de distros
│   └── etapa1_infraestructura_incus.md        # Paso a paso implementado
├── incus/
│   ├── profiles/                              # Perfiles de recursos por nodo
│   └── volumes/                               # Volúmenes persistentes
├── tofu/                                      # Archivos .tf (Etapa 2)
├── ansible/
│   ├── inventory/                             # Inventario de nodos
│   └── playbooks/                             # Configuración por rol
├── scripts/
│   ├── shutdown-lab.sh                        # Apagado ordenado
│   └── startup-lab.sh                         # Reinicio con OVN
└── README.md
```

---

## 🚀 Inicio Rápido

### Requisitos previos

- Windows 11 con WSL2 habilitado, **o** Linux con Incus instalado
- Mínimo 8 GiB RAM disponible para el host
- 70 GiB de espacio en disco

### 1. Configurar WSL2 (solo Windows)

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

Reiniciar el equipo.

### 2. Instalar Incus

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y incus
sudo incus admin init --minimal
sudo usermod -aG incus $USER && newgrp incus
```

### 3. Configurar red OVN

```bash
# Habilitar redes en el proyecto
sudo incus project set default features.networks=true

# Instalar OVN
sudo apt install -y ovn-host ovn-central
sudo /usr/share/ovn/scripts/ovn-ctl start_northd
sudo /usr/share/ovn/scripts/ovn-ctl start_controller

# Conectar OVS con OVN
sudo ovs-vsctl set open_vswitch . \
  external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock \
  external-ids:ovn-encap-type=geneve \
  external-ids:ovn-encap-ip=127.0.0.1

sudo incus config set network.ovn.northbound_connection \
  unix:/var/run/ovn/ovnnb_db.sock

# Crear bridge uplink + red OVN
sudo incus network create incusbr0 --type=bridge \
  ipv4.address=10.10.0.1/24 ipv4.nat=true

sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=10.10.0.100-10.10.0.200 \
  ipv4.ovn.ranges=10.10.0.10-10.10.0.50

sudo incus network create lab-net --type=ovn \
  network=incusbr0 ipv4.address=10.10.0.1/24 ipv4.nat=true
```

### 4. Lanzar el laboratorio

```bash
# Storage pool
sudo incus storage create default dir

# Crear perfiles, volúmenes y contenedores
# (ver docs/etapa1_infraestructura_incus.md para el detalle completo)

sudo incus launch images:debian/13 node-control  -p node-control  --network lab-net
sudo incus launch images:debian/13 app-api       -p app-api       --network lab-net
sudo incus launch images:debian/13 app-core      -p app-core      --network lab-net
sudo incus launch images:debian/13 db-postgres   -p db-postgres   --network lab-net
sudo incus launch images:debian/13 monitoring    -p monitoring    --network lab-net
sudo incus launch images:debian/13 ceph-node     -p ceph-node     --network lab-net
```

### 5. Verificar

```bash
sudo incus list
# Los 6 nodos deben aparecer RUNNING con IPs en 10.10.0.x

sudo incus exec node-control -- ping -c 2 10.10.0.5
# 0% packet loss ✅
```

---

## 🔄 Operación del Laboratorio

### Apagado ordenado

```bash
bash scripts/shutdown-lab.sh
```

El script detiene los nodos en orden seguro: aplicación → monitoreo → almacenamiento → base de datos → control.

### Reinicio

```bash
bash scripts/startup-lab.sh
```

El script levanta OVN primero (necesario en WSL2), luego los nodos en orden inverso.

---

## 🗺️ Roadmap

### ✅ Etapa 1 — Infraestructura Base (completada)

- [x] WSL2 + Ubuntu 24.04 como host
- [x] Incus 6.0.0 instalado y operativo
- [x] OVN + Open vSwitch configurados
- [x] Storage pool `default` creado
- [x] 6 perfiles con límites de CPU, RAM y disco
- [x] 5 volúmenes persistentes creados
- [x] Red OVN `lab-net` en `10.10.0.0/24`
- [x] 6 contenedores Debian 13 corriendo
- [x] Conectividad verificada (0% packet loss)

### 🔄 Etapa 2 — IaC y Configuración (14–22 mayo)

- [ ] OpenTofu instalado en `node-control`
- [ ] Infraestructura convertida a archivos `.tf`
- [ ] Playbooks Ansible por rol de nodo
- [ ] Despliegue automatizado desde cero

### 📅 Etapa 3 — Aplicación y Observabilidad

- [ ] API REST en `app-api` (FastAPI / Node.js)
- [ ] Lógica de negocio en `app-core`
- [ ] PostgreSQL configurado con esquema de reservas
- [ ] Prometheus recolectando métricas de todos los nodos
- [ ] Grafana con dashboards del clúster
- [ ] Test de recuperabilidad (destruir/recrear contenedor)

---

## 🐛 Problemas Conocidos y Soluciones

| Error | Causa | Solución |
|-------|-------|---------|
| `Network not allowed in project` | Proyecto default restringido | `sudo incus project set default features.networks=true` |
| `ovn-ctl: command not found` | Binario fuera del PATH | Usar `/usr/share/ovn/scripts/ovn-ctl` |
| `No root device could be found` | Perfiles sin disco asignado | Agregar device root con `size` explícito |
| `Missing ipv4.ovn.ranges` | Bridge sin rango OVN | Definir `ipv4.ovn.ranges` y `ipv4.dhcp.ranges` separados |
| OVN muerto tras reiniciar WSL2 | WSL2 no persiste servicios | `startup-lab.sh` levanta OVN manualmente al inicio |

---

## 📄 Licencia

MIT — libre para uso académico y personal.

---

*Proyecto académico — Mayo 2026*
