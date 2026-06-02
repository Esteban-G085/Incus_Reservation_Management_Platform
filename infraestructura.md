# Selección de Distribuciones Linux para la Plataforma de Gestión de Reservas sobre Incus

**Fecha:** Mayo 2026  
**Proyecto:** Plataforma de Gestión de Reservas - Laboratorio Académico sobre Incus  
**Criterio Principal:** Estabilidad máxima y recuperabilidad ante apagados/reinicios

---

## 1. Contexto y Requisitos

### Hardware Disponible

- **Procesador:** 16 CPUs
- **Memoria RAM:** 33.4 GB
- **Almacenamiento:** SSD (escritura activa: 567 KiB/s)
- **Host Físico:** Debian 13 (trixie)

### Nodos Lógicos del Proyecto

1. **ctl:** Orquestación y automatización (Ansible)
2. **api:** Punto de entrada REST de la aplicación
3. **core:** Lógica de negocio y validaciones
4. **db:** Persistencia de datos (usuarios, recursos, reservas)
5. **mon:** Observabilidad (Prometheus + Grafana)
6. **ceph:** Almacenamiento distribuido

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

- ❌ Host físico es Debian 13, no Ubuntu
- ❌ Fricción entre versiones: Ubuntu ≠ Debian en detalles de empaquetado
- ❌ Más superficie de incompatibilidades (librerías, kernels)
- ❌ Overhead innecesario en contenedores ligeros

**Veredicto:** Descartado por fricción entre host y contenedores.

---

### Opción 2: Especialización por Rol (Debian + Alpine + Ubuntu)

**Distribución:** Mezcla selectiva según nodo

- **ctl:** Debian 12 (herramientas CLI)
- **api, core:** Ubuntu 22.04 LTS (aplicación)
- **db:** Debian 12 slim (base de datos)
- **mon:** Ubuntu 22.04 LTS (Prometheus/Grafana)
- **ceph:** Alpine Linux 3.18 (almacenamiento ultraligero)

**Ventajas:**

- Optimización individual por rol
- Bajo consumo en algunos nodos

**Desventajas:**

- ❌ Múltiples sistemas de paquetes (apt, apk)
- ❌ Troubleshooting complejo (depende de qué distro sea)
- ❌ Fragmentación: si algo falla, ¿es por Alpine, Debian o Ubuntu?
- ❌ Violaría el principio "menos variables = más estable"
- ❌ Equipos académicos no tienen tiempo para debuguear 3 distros simultáneamente

**Veredicto:** Descartado por complejidad operacional y riesgo de cascadas de fallos.

---

### Opción 3: Uniformidad Total con Ubuntu 22.04 LTS

**Distribución:** Ubuntu 22.04 LTS en host + todos los contenedores  
**Ventajas:**

- Uniformidad total
- LTS robusto
- Comunidad grande

**Desventajas:**

- ❌ Requires instalar Ubuntu en host (costo de migración)
- ❌ Host ya corre Debian 13 exitosamente
- ❌ Cambio innecesario = riesgo innecesario

**Veredicto:** Descartado por cambio innecesario del host ya funcional.

---

## 3. Decisión Final: Uniformidad Total con Debian 13

### Selección Recomendada

| Nodo | Distribución | Versión | Justificación |
|------|--------------|---------|---------------|
| **Host Físico** | Debian 13 | trixie | Instalado, estable, soporte predecible |
| **ctl** | Debian 13 | trixie | Orquestación: Ansible, SSH sin fricción |
| **api** | Debian 13 | trixie | API REST: misma base = menos sorpresas en librerías |
| **core** | Debian 13 | trixie | Lógica de negocio: idem anterior |
| **db** | Debian 13 slim | trixie | PostgreSQL idéntico, imagen ultraligera (base de datos = cero margen de error) |
| **mon** | Debian 13 | trixie | Prometheus + Grafana sin overhead |
| **ceph** | Debian 13 | trixie | Almacenamiento: Ceph en Debian = comportamiento predecible |

### Ventajas de esta Decisión

✅ **Un solo kernel, una sola libc, un solo ecosistema de paquetes**

- Troubleshooting directo: "no es un problema de versiones de libc"
- Actualizaciones de seguridad uniformes

✅ **Consistencia host → contenedores**

- El comportamiento de un servicio en el host es idéntico en un contenedor
- Facilita porting de configuración

✅ **Debian 13 es legendariamente estable en apagados/reinicios**

- Mecanismos de shutdown predecibles
- Fsck consistente
- Recuperación de servicios robusta

✅ **Menos variables operacionales**

- Mismo package manager (apt) en todos lados
- Mismas rutas de configuración (/etc/*)
- Mismos mecanismos de systemd

✅ **Bajo overhead: margen de seguridad amplío**

- 16 CPUs totales, 13 comprometidas = 3 libres
- 33.4 GB RAM, ~10 GB asignado = 23 GB libres
- No hay presión de recursos

✅ **Soporte a largo plazo predecible**

- Debian 13 mantiene LTS tácito en su ecosystem
- Críticas de seguridad publicadas rápidamente

---

## 4. Configuración de Perfiles Incus

La configuración se encuentra centralizada en el script `scripts/profiles.sh`, el cual crea perfiles con los siguientes límites:

### Perfiles de Límites de Recursos

- **ctl:** 1 CPU, 512 MiB RAM
- **api:** 2 CPUs, 1024 MiB RAM
- **core:** 2 CPUs, 1536 MiB RAM
- **db:** 4 CPUs, 4096 MiB RAM
- **mon:** 2 CPUs, 1024 MiB RAM
- **ceph:** 2 CPUs, 2048 MiB RAM

### Cálculo de Recursos

| Nodo | CPUs | RAM | Total CPUs | Total RAM |
|------|------|-----|-----------|-----------|
| ctl | 1 | 512 MiB | 1 | 512 MiB |
| api | 2 | 1024 MiB | 2 | 1024 MiB |
| core | 2 | 1536 MiB | 2 | 1536 MiB |
| db | 4 | 4096 MiB | 4 | 4096 MiB |
| mon | 2 | 1024 MiB | 2 | 1024 MiB |
| ceph | 2 | 2048 MiB | 2 | 2048 MiB |
| **TOTAL** | **13** | **10240 MiB (~10 GiB)** | **13** | **10 GiB** |
| **Disponible** | **16** | **33.4 GiB** | — | — |
| **Margen** | **3** | **23.4 GiB** | **Suficiente** | **Suficiente** |

---

## 5. Configuración de Volúmenes Persistentes

### Principio de Diseño

**Regla de Oro:** Si elimino un contenedor, sus datos persisten en el volumen.  
Si reinicio el host, todos los volúmenes reaparecen y los contenedores los reclaman.

### Creación de Volúmenes y Montaje

La creación de volúmenes está automatizada mediante el script `scripts/volumes.sh` y el montaje en los contenedores se realiza durante el aprovisionamiento en `scripts/containers.sh`.

Los volúmenes creados son:

- **postgres-data**: Datos de PostgreSQL (db)
- **prometheus-data**: Histórico de métricas (mon)
- **grafana-data**: Dashboards y configuraciones (mon)
- **ceph-data**: Almacenamiento distribuido (ceph)
- **app-data**: Volumen compartido para la aplicación (api y core)

---

## 6. Procedimiento de Reproducción

Toda la infraestructura y configuración se ha modularizado en la carpeta `scripts/` para simplificar la gestión.

### Paso 1: Preparación de Red

Se ejecuta `scripts/network.sh` para crear y configurar la red `lab-net`.

**Detalles del script:**

- Verifica si la red OVN `lab-net` ya existe.
- Si no existe, la crea asignando explícitamente el rango IPv4 `10.10.0.1/24`.
- Habilita NAT (`ipv4.nat=true`) para permitir que los contenedores tengan salida a internet y se puedan instalar paquetes.

### Paso 2: Crear Perfiles y Volúmenes

Se ejecutan los scripts de preparación:

- `scripts/profiles.sh`: Crea todos los perfiles de recursos (`ctl`, `api`, etc.).
  **Detalles:** Define los límites exactos de CPU (`limits.cpu`) y memoria RAM (`limits.memory`) usando comandos `incus profile set`, garantizando que los contenedores no consuman más recursos del host de los permitidos. También adjunta el disco raíz (`root`) apuntando al pool por defecto.
- `scripts/volumes.sh`: Crea los volúmenes persistentes.
  **Detalles:** Emplea `incus storage volume create` para reservar en el storage pool por defecto los espacios requeridos (`postgres-data`, `prometheus-data`, `grafana-data`, `ceph-data`, `app-data`).

### Paso 3: Lanzar Contenedores

- Se ejecuta `scripts/containers.sh`. Este script lanza los contenedores (`ctl`, `api`, `core`, `db`, `mon`, `ceph`) y adjunta automáticamente los volúmenes persistentes.

  **Detalles del script:**
  - Es un proceso idempotente: verifica primero la existencia de cada contenedor o volumen antes de intentar crearlo (evitando errores si ya existen).
  - Descarga e instancia la imagen oficial `debian/13`.
  - Asigna la red `lab-net` y el perfil de recursos correspondiente a cada contenedor al lanzarlo.
  - Ejecuta `incus config device add` para montar los volúmenes específicos en las rutas deseadas (ej. montando `postgres-data` en `/var/lib/postgresql` dentro de `db`).

### Paso 4: Configurar Servicios

Se utilizan playbooks de Ansible, automatizados mediante el script:

- `scripts/setup-services.sh`: Instala dependencias (Python), genera el inventario (`inventory.ini`) y los playbooks, y los ejecuta para la base de datos, monitoreo y aplicación.

  **Detalles del script:**
  - Instala `ansible` en el host (si no está instalado) y la colección `community.general` para comunicarse fluidamente con los contenedores vía el socket de Incus.
  - Instala `python3` de manera iterativa dentro de cada contenedor (necesario para que Ansible funcione internamente).
  - Crea un archivo de inventario dinámico con los grupos de hosts (`control`, `app`, `database`, `monitoring`, `storage`).
  - Escribe en tiempo real múltiples Playbooks: *Base* (curl, wget, vim), *DB* (PostgreSQL), *Monitoreo* (Prometheus+Grafana), y *App* (FastAPI+venv).
  - Ejecuta todos los playbooks y finalmente realiza una verificación usando `systemctl is-active`.

### Paso 5: Validación

- Ejecutar `scripts/validate.sh` o `scripts/validate-services.sh` para verificar el estado de los contenedores, conectividad de red, volúmenes y la disponibilidad de los servicios (PostgreSQL, Prometheus, Grafana, API).

  **Detalles de los scripts:**
  - Validan que los contenedores estén en estado `RUNNING` usando `incus list`.
  - Hacen pruebas de ping de contenedor a contenedor para asegurar que la resolución DNS de `lab-net` y el enrutamiento están operando.
  - Comprueban que los servicios base respondan por dentro (por ejemplo, ejecutando utilidades de verificación o checando procesos systemd como `grafana-server`).

---

## 7. Procedimiento de Apagado y Reinicio Seguro

Se dispone de scripts dedicados en la carpeta `scripts/` para gestionar el ciclo de vida de todo el laboratorio, garantizando apagados gráciles y el orden correcto de inicio:

- **Apagado (`scripts/shutdown.sh`):** Ejecutar este script para detener de forma ordenada los servicios: aplicación -> monitoreo -> almacenamiento -> base de datos -> control.
  **Detalles:** Utiliza comandos `incus stop` escalonados con pausas (`sleep`) entre fases para dar tiempo a que los contenedores cierren sus conexiones a bases de datos y purguen procesos a disco de manera natural. Esto es vital para prevenir la corrupción de los volúmenes, especialmente en PostgreSQL (`db`) y Ceph (`ceph`).

- **Reinicio (`scripts/startup.sh`):** Ejecutar este script para iniciar los contenedores en el orden inverso: almacenamiento -> base de datos -> monitoreo -> aplicación -> control.
  **Detalles:** Emplea `incus start`, garantizando el orden de dependencias. Por ejemplo, asegura que los nodos de almacenamiento y de bases de datos estén plenamente activos y listos para recibir conexiones (con retardos intencionales mayores a 5 segundos) antes de intentar arrancar la API, evitando condiciones de carrera donde la API podría crashear al no encontrar su base de datos.

---

## 8. Checklist de Implementación

- [ ] Host Debian 13 instalado y actualizado
- [ ] Incus instalado e inicializado
- [ ] Red OVN creada (`lab-net`) mediante `scripts/network.sh`
- [ ] Perfiles y volúmenes creados (`scripts/profiles.sh` y `scripts/volumes.sh`)
- [ ] Contenedores lanzados (`scripts/containers.sh`)
- [ ] Servicios instalados y configurados (`scripts/setup-services.sh`)
- [ ] Validación completada (`scripts/validate.sh`)
- [ ] Test de recuperabilidad completado
- [ ] Scripts de apagado probados sin errores (`scripts/shutdown.sh`)
- [ ] Scripts de reinicio probados sin errores (`scripts/startup.sh`)
- [ ] Documentación de operación completada

## 9. Referencias

- [Incus Documentation](https://linuxcontainers.org/incus/)
- [Debian 13 Release Notes](https://www.debian.org/releases/trixie/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Prometheus Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [PostgreSQL Administration](https://www.postgresql.org/docs/15/admin.html)

---

**Documento de Decisión Técnica - Proyecto Incus 2026**  
*Estabilidad por Simplicidad y Uniformidad*
