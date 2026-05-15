# 🖥️ Plataforma de Gestión de Reservas sobre Incus

> Laboratorio académico de infraestructura como código: 6 contenedores Debian 13 orquestados con Incus, OVN y automatizados con OpenTofu + Ansible.

![Estado](https://img.shields.io/badge/Etapa%201-Completada-brightgreen)
![Incus](https://img.shields.io/badge/Incus-6.0.0-blue)
![Debian](https://img.shields.io/badge/Contenedores-Debian%2013-red)
![Plataforma](https://img.shields.io/badge/Host-WSL2%20%2B%20Ubuntu%2024.04-orange)

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

| Nodo | CPUs | RAM | Disco |
|------|:----:|:---:|:-----:|
| node-control | 1 | 256 MiB | 4 GiB |
| app-api | 1 | 768 MiB | 8 GiB |
| app-core | 1 | 768 MiB | 8 GiB |
| db-postgres | 2 | 2 GiB | 20 GiB |
| monitoring | 2 | 1.5 GiB | 10 GiB |
| ceph-node | 1 | 512 MiB | 15 GiB |
| **Total** | **8** | **~5.75 GiB** | **65 GiB** |

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


*Proyecto académico — Mayo 2026*
