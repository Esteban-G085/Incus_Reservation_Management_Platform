# Etapa 2 — Infraestructura como Código con OpenTofu

**Proyecto:** Plataforma de Gestión de Reservas sobre Incus  
**Fecha:** Mayo 2026  
**Entorno:** Windows 11 + WSL2 + Ubuntu 24.04  
**Herramienta:** OpenTofu v1.9.0 + Provider `lxc/incus` v0.5.1  

---

## 1. Objetivo

Convertir la infraestructura manual de la Etapa 1 (6 contenedores, 6 perfiles, red OVN, storage pool) en código declarativo reproducible mediante **OpenTofu** (IaC).

---

## 2. Decisiones Técnicas

| Decisión | Justificación |
|----------|---------------|
| **Ejecutar OpenTofu desde WSL2 (host)** | `node-control` no tenía acceso a Internet (fallo de red OVN). El host WSL2 tiene conectividad y acceso directo al socket de Incus. |
| **Gestionar solo perfiles + contenedores + pool** | El provider `lxc/incus` v0.5.1 tiene bugs conocidos al importar redes tipo `bridge` y volúmenes persistentes. Se documentan como infraestructura base creada en Etapa 1. |
| **Usar `sudo` para `tofu plan/apply`** | Los recursos de Incus fueron creados con `sudo` en la Etapa 1, por lo que el provider necesita privilegios elevados para leerlos. |
| **Usar `import` blocks (OpenTofu moderno)** | Más predecibles que `tofu import` CLI. Se procesan durante `tofu plan` y permiten importar en bloque. |

---

## 3. Instalación de OpenTofu

### 3.1 En WSL2 (host)

```bash
# Descargar binario pre-compilado
curl -fsSL https://github.com/opentofu/opentofu/releases/download/v1.9.0/tofu_1.9.0_linux_amd64.zip -o /tmp/tofu.zip
cd /tmp && unzip -o tofu.zip

# Instalar permanentemente
sudo cp /tmp/tofu /usr/local/bin/tofu
sudo chmod +x /usr/local/bin/tofu

# Verificar
tofu version
# OpenTofu v1.9.0 on linux_amd64
```

### 3.2 En node-control (descartado)

Se intentó instalar OpenTofu dentro del contenedor `node-control` vía repositorio APT, pero falló por falta de conectividad a Internet (DNS no resolvía, gateway `10.10.0.1` no respondía). Se optó por la estrategia del host.

---

## 4. Estructura del Proyecto

```
~/lab-reservas/tofu/
├── .terraform/
│   └── providers/
├── .terraform.lock.hcl
├── versions.tf      # Versiones de OpenTofu y provider
├── provider.tf      # Conexión al socket local de Incus
├── variables.tf     # Configuración centralizada
├── main.tf          # Recursos gestionados
├── outputs.tf       # Salidas útiles
└── imports.tf       # Importación de infra existente (eliminado tras import)
```

---

## 5. Archivos de Configuración

### 5.1 versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    incus = {
      source  = "registry.opentofu.org/lxc/incus"
      version = "~> 0.3"
    }
  }
}
```

### 5.2 provider.tf

```hcl
provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true
}
```

### 5.3 variables.tf

Define:

- `network_name`, `network_cidr`, `uplink_bridge`
- `storage_pool`, `storage_pool_driver`
- `image` base (`images:debian/13`)
- Mapa `nodes` con CPU, RAM, disco e IP de cada contenedor
- Lista `volumes` de volúmenes persistentes

### 5.4 main.tf (versión final)

Gestiona 3 tipos de recursos:

- `incus_storage_pool.default` — pool `default` tipo `dir`
- `incus_profile.node` — 6 perfiles (for_each sobre var.nodes)
- `incus_instance.node` — 6 contenedores Debian 13 (for_each)

**Nota:** Redes y volúmenes se referencian como strings literales (`network = "lab-net"`) en lugar de recursos gestionados, debido a limitaciones del provider.

### 5.5 outputs.tf

```hcl
output "profiles" {
  description = "Perfiles creados"
  value       = [for p in incus_profile.node : p.name]
}

output "containers" {
  description = "Contenedores gestionados"
  value       = [for c in incus_instance.node : c.name]
}
```

---

## 6. Problemas Encontrados y Soluciones

| # | Problema | Causa | Solución |
|---|----------|-------|----------|
| 1 | `node-control` sin Internet | Gateway `10.10.0.1` no responde dentro del contenedor; DNS no resuelve | Ejecutar OpenTofu desde **WSL2 host** en lugar de `node-control` |
| 2 | `Cannot import non-existent remote object` (incusbr0) | El provider `lxc/incus` v0.5.1 no soporta bien la importación de redes tipo `bridge` | **Excluir** redes de la gestión de OpenTofu; documentarlas como infra base |
| 3 | `Invalid import ID` (volúmenes) | El provider espera formato `[<remote>:][<project>]/<pool>/<name>`; `default/postgres-data` era inválido | **Excluir** volúmenes de la gestión de OpenTofu; documentarlos como infra base |
| 4 | `User does not have permission for project "default"` (contenedores) | Los recursos fueron creados con `sudo`; el provider sin sudo no puede leer instancias | Ejecutar `sudo tofu plan` y `sudo tofu apply` |
| 5 | `tofu import` CLI fallaba con perfiles en for_each | Sintaxis compleja de IDs con comillas y corchetes | Usar **import blocks** en archivo `.tf` en lugar de comando CLI |

---

## 7. Proceso de Importación

### 7.1 imports.tf original (antes de limpiar)

Se creó un archivo con 13 bloques `import`:

- 1 storage pool
- 6 perfiles
- 6 contenedores

### 7.2 Comando de validación

```bash
cd ~/lab-reservas/tofu
tofu validate
# Success! The configuration is valid.
```

### 7.3 Plan de importación

```bash
sudo tofu plan
```

Salida esperada:

```
Plan: 6 to import, 0 to add, 0 to change, 0 to destroy.
```

(Nota: el storage pool ya había sido importado previamente con `tofu import`)

### 7.4 Aplicar importación

```bash
sudo tofu apply
# Confirma con "yes"
```

### 7.5 Verificación final

```bash
sudo tofu state list
```

Resultado:

```
incus_instance.node["app-api"]
incus_instance.node["app-core"]
incus_instance.node["ceph-node"]
incus_instance.node["db-postgres"]
incus_instance.node["monitoring"]
incus_instance.node["node-control"]
incus_profile.node["app-api"]
incus_profile.node["app-core"]
incus_profile.node["ceph-node"]
incus_profile.node["db-postgres"]
incus_profile.node["monitoring"]
incus_profile.node["node-control"]
incus_storage_pool.default
```

### 7.6 Plan final (0 cambios)

```bash
sudo tofu plan
# No changes. Your infrastructure matches the configuration.
```

---

## 8. Estado Final de la Infraestructura

| Recurso | Origen | Gestión |
|---------|--------|---------|
| Storage pool `default` | Etapa 1 | ✅ OpenTofu |
| Bridge `incusbr0` | Etapa 1 | ⚠️ Existente, no gestionado |
| Red OVN `lab-net` | Etapa 1 | ⚠️ Existente, no gestionado |
| 6 Perfiles | Etapa 1 | ✅ OpenTofu |
| 5 Volúmenes persistentes | Etapa 1 | ⚠️ Existentes, no gestionados |
| 6 Contenedores Debian 13 | Etapa 1 | ✅ OpenTofu |

**Total gestionado por OpenTofu: 13 recursos**

---

## 9. Comandos Clave de Referencia

```bash
# Validar sintaxis
tofu validate

# Ver plan (previsualizar cambios)
sudo tofu plan

# Aplicar cambios
sudo tofu apply

# Listar recursos en estado
sudo tofu state list

# Destruir infraestructura (NO ejecutar en este lab sin backup)
sudo tofu destroy
```

---

## 10. Lecciones Aprendidas

1. **El provider de Incus es funcional pero tiene rough edges.** Las redes y volúmenes requieren trabajo manual o data sources; no todos los recursos se importan limpiamente.

2. **Ejecutar IaC desde el host es más pragmático** que desde dentro de un contenedor con problemas de red, especialmente en entornos WSL2.

3. **`sudo` es necesario** cuando la infra fue creada con `sudo` originalmente. Los permisos de proyecto en Incus son estrictos.

4. **Los `import` blocks son superiores al CLI `tofu import`** para recursos con `for_each`, porque evitan la sintaxis compleja de IDs con comillas y corchetes.

5. **Documentar lo que NO se gestiona es tan importante** como documentar lo que sí. Las redes y volúmenes existen, funcionan, pero quedan fuera del ciclo de vida de OpenTofu por limitaciones del provider.

---

## 11. Checklist Etapa 2

- [x] OpenTofu v1.9.0 instalado en WSL2
- [x] Provider `lxc/incus` v0.5.1 descargado e inicializado
- [x] Estructura de proyecto `~/lab-reservas/tofu/` creada
- [x] Archivos `.tf` versionables: versions, provider, variables, main, outputs
- [x] 13 recursos importados al estado de OpenTofu
- [x] `tofu plan` reporta **0 cambios** (infra sincronizada)
- [x] `imports.tf` eliminado (ya no necesario)
- [x] Documentación de problemas y soluciones

---
