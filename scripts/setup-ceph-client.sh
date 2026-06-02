#!/bin/bash
# setup-ceph-client.sh - Configura api y core como clientes Ceph
# Requisito: setup-ceph.sh ya ejecutado, cluster Ceph HEALTH_OK

set -e

echo "=========================================="
echo "  CONFIGURACIÓN CLIENTES CEPH - api + core"
echo "=========================================="
echo ""

# Verificar que el contenedor ceph esté accesible
if ! sudo incus exec ceph -- ceph -s &>/dev/null; then
  echo "ERROR: No se puede acceder al cluster Ceph"
  echo "Ejecuta primero: sudo bash scripts/setup-ceph.sh"
  exit 1
fi

CLUSTER_STATUS=$(sudo incus exec ceph -- ceph -s --format json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('health','').get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
echo "Estado del cluster Ceph: $CLUSTER_STATUS"

# Copiar ceph.conf y keyring a cada contenedor
for CONTAINER in api core; do
  echo ""
  echo "--- Configurando $CONTAINER ---"

  echo "[1/4] Instalando ceph-common..."
  sudo incus exec "$CONTAINER" -- apt install -y ceph-common -qq > /dev/null 2>&1
  echo "  OK"

  echo "[2/4] Copiando ceph.conf..."
  sudo incus exec "$CONTAINER" -- mkdir -p /etc/ceph
  sudo incus file pull ceph/etc/ceph/ceph.conf - | sudo incus file push - "$CONTAINER"/etc/ceph/ceph.conf
  echo "  OK"

  echo "[3/4] Copiando keyring client.reservas..."
  sudo incus file pull ceph/etc/ceph/ceph.client.reservas.keyring - | sudo incus file push - "$CONTAINER"/etc/ceph/ceph.client.reservas.keyring
  echo "  OK"

  echo "[4/4] Probando conectividad con Ceph..."
  if sudo incus exec "$CONTAINER" -- ceph -s --name client.reservas &>/dev/null; then
    echo "  ✅ $CONTAINER → Ceph: conectividad OK"
  else
    echo "  ❌ $CONTAINER → Ceph: falló conexión"
  fi
done

echo ""
echo "=========================================="
echo "  ✅ CLIENTES CEPH CONFIGURADOS"
echo "=========================================="
echo ""
echo "Pruebas rápidas:"
echo "  sudo incus exec api -- rados -p reservas-pool --name client.reservas ls"
echo "  sudo incus exec core -- rados -p reservas-pool --name client.reservas ls"
echo "  sudo incus exec api -- ceph -s --name client.reservas"
echo ""
