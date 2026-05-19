#!/bin/bash
# setup-services.sh
# Instala y configura servicios dentro de los contenedores via Ansible.
# Prerequisito: setup-lab.sh ya fue ejecutado y los 6 contenedores están RUNNING.

set -e

REPO_DIR="$HOME/Incus_Reservation_Management_Platform"

echo "=========================================="
echo "  SETUP DE SERVICIOS (Ansible)"
echo "=========================================="
echo ""

# ─── 1. Ansible en el host ────────────────────────────────────────────────────
echo "[1/6] Verificando Ansible en el host..."
if ! command -v ansible &>/dev/null; then
  echo "  Instalando Ansible..."
  sudo apt install -y ansible
else
  echo "  OK: Ansible $(ansible --version | head -1 | awk '{print $3}')"
fi

ansible-galaxy collection install community.general --quiet
echo "  OK: community.general instalada"
echo ""

# ─── 2. Python3 en todos los contenedores ─────────────────────────────────────
echo "[2/6] Instalando Python3 en contenedores..."
for c in ctl api core db mon ceph; do
  if incus exec "$c" -- which python3 &>/dev/null; then
    echo "  OK: $c ya tiene python3"
  else
    echo "  Instalando python3 en $c..."
    incus exec "$c" -- apt install -y python3 -q
    echo "  OK: $c"
  fi
done
echo ""

# ─── 3. Inventario ────────────────────────────────────────────────────────────
echo "[3/6] Generando inventory.ini..."
cat > "$REPO_DIR/inventory.ini" << 'EOF'
[all:vars]
ansible_connection=community.general.incus
ansible_incus_remote=local
ansible_python_interpreter=/usr/bin/python3.13

[all]
ctl
api
core
db
mon
ceph

[control]
ctl

[app]
api
core

[database]
db

[monitoring]
mon

[storage]
ceph
EOF
echo "  OK: inventory.ini generado"
echo ""

# ─── 4. Playbooks ─────────────────────────────────────────────────────────────
echo "[4/6] Generando playbooks..."

# Base
cat > "$REPO_DIR/playbook-base.yml" << 'EOF'
---
- hosts: all
  become: true
  tasks:
    - name: Actualizar repositorios
      apt:
        update_cache: yes

    - name: Instalar paquetes base
      apt:
        name:
          - curl
          - wget
          - git
          - vim
          - net-tools
        state: present
EOF

# PostgreSQL
cat > "$REPO_DIR/playbook-db.yml" << 'EOF'
---
- hosts: database
  become: true
  tasks:
    - name: Instalar PostgreSQL
      apt:
        name:
          - postgresql
          - postgresql-client
        state: present

    - name: Habilitar e iniciar PostgreSQL
      systemd:
        name: postgresql
        enabled: yes
        state: started

    - name: Verificar que PostgreSQL responde
      command: pg_isready
      register: pg_status
      changed_when: false

    - name: Mostrar estado de PostgreSQL
      debug:
        msg: "{{ pg_status.stdout }}"
EOF

# Monitoring
cat > "$REPO_DIR/playbook-mon.yml" << 'EOF'
---
- hosts: monitoring
  become: true
  tasks:
    - name: Instalar dependencias
      apt:
        name:
          - apt-transport-https
          - gnupg
          - wget
        state: present

    - name: Instalar Prometheus
      apt:
        name: prometheus
        state: present

    - name: Habilitar e iniciar Prometheus
      systemd:
        name: prometheus
        enabled: yes
        state: started

    - name: Agregar repo de Grafana
      shell: |
        wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
        echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
      args:
        creates: /etc/apt/sources.list.d/grafana.list

    - name: Actualizar repositorios
      apt:
        update_cache: yes

    - name: Instalar Grafana
      apt:
        name: grafana
        state: present

    - name: Habilitar e iniciar Grafana
      systemd:
        name: grafana-server
        enabled: yes
        state: started

    - name: Verificar Prometheus
      command: systemctl is-active prometheus
      register: prom_status
      changed_when: false

    - name: Verificar Grafana
      command: systemctl is-active grafana-server
      register: graf_status
      changed_when: false

    - name: Mostrar estado
      debug:
        msg: "Prometheus: {{ prom_status.stdout }} | Grafana: {{ graf_status.stdout }}"
EOF

# App (api + core)
cat > "$REPO_DIR/playbook-app.yml" << 'EOF'
---
- hosts: app
  become: true
  tasks:
    - name: Instalar Python y pip
      apt:
        name:
          - python3-pip
          - python3-venv
          - python3-dev
          - build-essential
        state: present

    - name: Crear directorio de la app
      file:
        path: /app
        state: directory
        mode: '0755'

    - name: Crear entorno virtual
      command: python3 -m venv /app/venv
      args:
        creates: /app/venv

    - name: Instalar FastAPI y uvicorn
      pip:
        name:
          - fastapi
          - uvicorn
          - httpx
        virtualenv: /app/venv

    - name: Verificar instalación
      command: /app/venv/bin/python -c "import fastapi; print('FastAPI', fastapi.__version__)"
      register: fastapi_version
      changed_when: false

    - name: Mostrar versión
      debug:
        msg: "{{ fastapi_version.stdout }}"
EOF

echo "  OK: playbooks generados"
echo ""

# ─── 5. Ejecutar playbooks ────────────────────────────────────────────────────
echo "[5/6] Ejecutando playbooks..."
cd "$REPO_DIR"

echo ""
echo "  --- Base (todos los contenedores) ---"
ansible-playbook -i inventory.ini playbook-base.yml

echo ""
echo "  --- PostgreSQL (db) ---"
ansible-playbook -i inventory.ini playbook-db.yml

echo ""
echo "  --- Prometheus + Grafana (mon) ---"
ansible-playbook -i inventory.ini playbook-mon.yml

echo ""
echo "  --- FastAPI (api + core) ---"
ansible-playbook -i inventory.ini playbook-app.yml

echo ""

# ─── 6. Verificación rápida ───────────────────────────────────────────────────
echo "[6/6] Verificación rápida de servicios..."
echo ""

check_service() {
  local container=$1
  local service=$2
  local status
  status=$(incus exec "$container" -- systemctl is-active "$service" 2>/dev/null || echo "not-found")
  if [ "$status" = "active" ]; then
    echo "  ✅ $container → $service: active"
  else
    echo "  ❌ $container → $service: $status"
  fi
}

check_service db postgresql
check_service mon prometheus
check_service mon grafana-server

echo ""
echo "=========================================="
echo "  ✅ SETUP DE SERVICIOS COMPLETADO"
echo "=========================================="
