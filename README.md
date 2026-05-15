# 🖥️ Plataforma de Gestión de Reservas sobre Incus

> Laboratorio académico de infraestructura como código: 6 contenedores Debian 13 orquestados con Incus, OVN y automatizados con OpenTofu + Ansible.

![Estado](https://img.shields.io/badge/Etapa%201-Completada-brightgreen)
![Estado](https://img.shields.io/badge/Etapa%202-Completada-brightgreen)
![Incus](https://img.shields.io/badge/Incus-6.0.0-blue)
![Debian](https://img.shields.io/badge/Contenedores-Debian%2013-red)
![Plataforma](https://img.shields.io/badge/Host-WSL2%20%2B%20Ubuntu%2024.04-orange)
![OpenTofu](https://img.shields.io/badge/OpenTofu-v1.9.0-purple)

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
| IaC | OpenTofu v1.9.0 *(Etapa 2)* |
| Configuración | Ansible *(pendiente)* |
| Base de datos | PostgreSQL 15 |
| Observabilidad | Prometheus + Grafana |
| Almacenamiento | Ceph |
| UI de gestión | Incus UI Web *(opcional)* |

---

## 📁 Estructura del Repositorio

```
.
├── docs/
│   ├── etapa1_infraestructura_incus.md        # Infraestructura base (Etapa 1)
│   ├── etapa1_infraestructura_incus_v2.md     # Versión mejorada con lecciones
│   └── etapa2_iac_opentofu.md               # Infraestructura como Código (Etapa 2)
├── tofu/                                      # Archivos .tf de OpenTofu
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
├── ansible/                                   # (pendiente)
│   ├── inventory/
│   └── playbooks/
├── scripts/
│   ├── setup-lab.sh                           # Creación completa del laboratorio
│   ├── start-lab.sh                           # Arranque ordenado (OVN + contenedores)
│   ├── stop-lab.sh                            # Apagado limpio
│   └── shutdown-lab.sh                        # Alias legacy de stop-lab.sh
└── README.md
```

---

## 🚀 Uso Rápido — Scripts

### 1. Crear el laboratorio desde cero

```bash
# Clonar o navegar al repositorio
cd ~/plataforma-reservas-incus

# Dar permisos de ejecución
chmod +x scripts/*.sh

# Crear infraestructura completa
./scripts/setup-lab.sh
```

**Qué hace:**

- Verifica Incus, OVN y Open vSwitch
- Crea storage pool `default`
- Crea bridge uplink `incusbr0` y red OVN `lab-net`
- Crea 6 perfiles con límites de CPU, RAM y disco
- Crea 5 volúmenes persistentes
- Lanza 6 contenedores Debian 13
- Verifica conectividad (ping desde `node-control`)

### 2. Arrancar el laboratorio (después de reiniciar WSL2)

```bash
./scripts/start-lab.sh
```

**Qué hace:**

- Verifica e inicia Open vSwitch (si está detenido)
- Inicia OVN northd y controller
- Inicia contenedores en orden de dependencias:
  1. `ceph-node` (almacenamiento base)
  2. `db-postgres` (base de datos)
  3. `monitoring` (observabilidad)
  4. `app-core` (lógica de negocio)
  5. `app-api` (API REST)
  6. `node-control` (orquestación)
- Espera 5 segundos para IPs
- Verifica conectividad entre nodos

> ⚠️ **Importante:** OVN se detiene cuando WSL2 se apaga. Este script debe ejecutarse siempre después de reiniciar WSL2.

### 3. Apagar el laboratorio

```bash
./scripts/stop-lab.sh
```

**Qué hace:**

- Detiene contenedores en orden inverso de dependencias:
  1. `node-control`
  2. `app-api`
  3. `app-core`
  4. `monitoring`
  5. `db-postgres`
  6. `ceph-node`
- Detiene OVN controller
- Detiene OVN northd
- Muestra estado final

> 💡 **Tip:** Es seguro ejecutar este script antes de cerrar WSL2 o apagar Windows. Los datos persistentes se mantienen.

---

## 🖥️ UI Web de Incus (Opcional)

Para gestionar contenedores, redes y recursos desde navegador:

### Instalación

```bash
sudo apt install -y incus-ui-canonical
```

### Configuración

```bash
# Escuchar solo en localhost (más seguro)
sudo incus config set core.https_address 127.0.0.1:8443
```

### Acceso

1. Abrir navegador en `https://localhost:8443`
2. Aceptar certificado autofirmado (self-signed)
3. Generar token de autenticación:

   ```bash
   sudo incus config trust add incus-ui
   ```

4. Pegar el token en la UI → Import → Listo

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
- [x] Scripts `setup-lab.sh`, `start-lab.sh`, `stop-lab.sh` creados y probados

### ✅ Etapa 2 — IaC con OpenTofu (completada)

- [x] OpenTofu v1.9.0 instalado en WSL2 (host)
- [x] Infraestructura convertida a archivos `.tf`
- [x] 13 recursos importados al estado de OpenTofu:
  - 1 storage pool
  - 6 perfiles
  - 6 contenedores
- [x] `tofu plan` reporta **0 cambios** (infra sincronizada)
- [x] Documentación de problemas y soluciones de IaC
- [x] UI Web de Incus instalada y configurada

### 🔄 Etapa 2b — Configuración con Ansible (pendiente)

- [ ] Ansible instalado en WSL2
- [ ] SSH configurado en los 6 contenedores
- [ ] Inventario dinámico con IPs de Incus
- [ ] Playbooks por rol (PostgreSQL, API, Monitoring, Ceph)

### 📅 Etapa 3 — Aplicación y Observabilidad

- [ ] API REST en `app-api` (FastAPI / Node.js)
- [ ] Lógica de negocio en `app-core`
- [ ] PostgreSQL configurado con esquema de reservas
- [ ] Prometheus recolectando métricas de todos los nodos
- [ ] Grafana con dashboards del clúster
- [ ] Test de recuperabilidad (destruir/recrear contenedor)

---

## 🛠️ Alternativas y Decisiones Técnicas

### ¿Por qué WSL2 en lugar de Linux físico?

El enunciado original asume un host Linux dedicado. Se optó por WSL2 para demostrar reproducibilidad en hardware de desarrollo cotidiano. **Limitación documentada:** los contenedores con red OVN pierden acceso a Internet (gateway no enruta a WAN).

### ¿Por qué OpenTofu desde WSL2 y no desde `node-control`?

Se intentó instalar OpenTofu dentro del contenedor `node-control`, pero falló por falta de conectividad a Internet (DNS no resolvía, gateway `10.10.0.1` no respondía). La solución pragmática fue ejecutar OpenTofu desde el **host WSL2**, que tiene acceso directo al socket de Incus.

### ¿Por qué no gestionar redes y volúmenes con OpenTofu?

El provider `lxc/incus` v0.5.1 tiene bugs conocidos al importar redes tipo `bridge` y volúmenes persistentes. Se documentan como infraestructura base creada en Etapa 1 y se referencian como strings literales en los archivos `.tf`.

### ¿Por qué Debian 13 en todos los contenedores?

Uniformidad: un solo ecosistema de paquetes (`apt`), troubleshooting directo, bajo consumo de recursos. El análisis completo de selección de distribuciones está documentado en la primera versión del proyecto.

---

## 📚 Documentación

| Documento | Contenido |
|-----------|-----------|
| `docs/etapa1_infraestructura_incus.md` | Paso a paso de la Etapa 1 |
| `docs/etapa2_iac_opentofu.md` | Infraestructura como Código con OpenTofu |
| `scripts/setup-lab.sh` | Creación completa del laboratorio |
| `scripts/start-lab.sh` | Arranque ordenado |
| `scripts/stop-lab.sh` | Apagado limpio |

---

## 🔧 Comandos Útiles de Referencia

```bash
# Ver estado de contenedores
sudo incus list

# Ver redes
sudo incus network list

# Ver perfiles
sudo incus profile list

# Ver volúmenes
sudo incus storage volume list default

# Entrar a un contenedor
sudo incus exec <nombre> -- bash

# Ver logs de un contenedor
sudo incus log <nombre>

# OpenTofu — ver plan (desde ~/lab-reservas/tofu)
cd ~/lab-reservas/tofu
sudo tofu plan

# OpenTofu — listar recursos gestionados
sudo tofu state list

# UI Web de Incus
https://localhost:8443
```
