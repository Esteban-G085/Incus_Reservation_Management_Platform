# MEMORY.md - Decision and Context Log

Este archivo documenta las decisiones tomadas por los agentes y humanos en este repositorio, siguiendo la regla global definida para el proyecto.

## Análisis y Refactorización del Repositorio (18 de Mayo, 2026)

### Propósito del Proyecto

Laboratorio de microservicios basado en contenedores **Incus** sobre **Debian 13 (Trixie)** para una plataforma de gestión de reservas. Diseñado para máxima estabilidad (KISS).

### Estructura de Componentes

- **Orquestación:** Contenedor `ctl` (control) para utilidades.
- **Aplicación:** `api` (entrada REST) y `core` (lógica de negocio).
- **Persistencia:** `db` con PostgreSQL y volúmenes persistentes.
- **Observabilidad:** `mon` con Prometheus y Grafana.
- **Almacenamiento:** `ceph` para almacenamiento distribuido.

### Infraestructura de Red

- Uso de **OVN (Open Virtual Network)** para aislamiento.
- Red `lab-net` (10.10.0.0/24) sin NAT, aislada del host.

### Evolución de la Automatización (Bash scripting)

Se tomó la decisión técnica de descartar OpenTofu/Terraform en favor de scripts modulares en Bash, por su nulo overhead, facilidad de depuración en entornos académicos y falta de dependencias externas pesadas.

Los scripts clave en la carpeta `scripts/`:
- `incusinstall.sh`: Instalación de dependencias (Zabbly, OVN, Incus).
- `network.sh`, `profiles.sh`, `volumes.sh`, `containers.sh`: Capa de Infraestructura (IaC minimalista).
- `setup-services.sh`: Capa de Configuración (ejecuta Ansible de forma automatizada sobre Incus sockets).
- `startup.sh` / `shutdown.sh`: Gestión segura del ciclo de vida.
- `validate.sh`: Testeo del sistema.

### Documentación de Referencia

- `infraestructura.md`: Fuente de Verdad. Justificación técnica y explicación al detalle de qué hace cada script en el background.
- `choices.md`: Historial o Log de cambios técnicos y estado del despliegue.
- `setupnetwork.md`: Guía de teoría de red OVN (opcional/contextual).

---

## Log de Decisiones

### 13 de Mayo, 2026 - Adquisición de Contexto Inicial

- **Decisión:** Lectura exhaustiva de todos los archivos `.md` y `.sh` para comprender el estado actual del proyecto.
- **Resultado:** Identificación de la infraestructura base.

### 18 de Mayo, 2026 - Modularización y Documentación KISS

- **Decisión:** Migración de comandos crudos a una suite de Scripts (`scripts/`).
- **Decisión:** Descartar `incussetup.md` por contener información redundante y obsoleta. Centralizar toda la teoría de perfiles en `infraestructura.md`.
- **Decisión:** Actualizar `infraestructura.md` para que contenga explicaciones "under-the-hood" sobre lo que hace cada script, manteniendo los archivos markdown limpios pero informativos.
- **Razón:** Seguir el principio KISS (Keep It Simple, Stupid) logrando que cualquier administrador o estudiante pueda instanciar y auditar el laboratorio sin curva de aprendizaje pronunciada (como la de OpenTofu).
- **Resultado:** Repositorio saneado, con documentación reflejando el código exacto a ejecutarse.

### 01 de Junio, 2026 - Implementación de Ceph Storage

- **Decisión:** Creación de `scripts/setup-ceph.sh` para configurar un cluster Ceph de un solo nodo dentro del contenedor `ceph`.
- **Decisión:** Uso de loop device (5GB) con BlueStore para el OSD, requiriendo `security.privileged=true` en el contenedor.
- **Decisión:** Creación de `scripts/setup-ceph-client.sh` para configurar `api` y `core` como clientes Ceph.
- **Decisión:** Actualización de `startup.sh`/`shutdown.sh` para orden correcto (ceph primero en startup, último en shutdown).
- **Decisión:** Actualización de `validate-services.sh` con checks de Ceph.
- **Razón:** Ceph proporciona almacenamiento distribuido objeto/bloque que complementa PostgreSQL y el volumen `app-data`.
- **Resultado:** Cluster Ceph con MON + MGR + OSD + pool `reservas-pool`, accesible desde `api` y `core`.
