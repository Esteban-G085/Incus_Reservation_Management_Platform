#!/bin/bash
# setup-ceph.sh - Configuración de Ceph Storage en contenedor ceph
# Requisito: contenedor ceph existente con security.privileged=true
# Crea MON + MGR + OSD (BlueStore sobre archivo, sin loop/LVM) + pool reservas-pool
# Nota: usa auth=none durante bootstrap, luego activa cephx.

set -e

echo "=========================================="
echo "  CONFIGURACIÓN DE CEPH STORAGE - ceph"
echo "=========================================="
echo ""

# Verificar que el contenedor esté RUNNING
STATE=$(sudo incus list ceph --format csv --columns s 2>/dev/null | head -1)
if [ "$STATE" != "RUNNING" ]; then
  echo "ERROR: El contenedor ceph no está RUNNING (estado: $STATE)"
  echo "Ejecuta: sudo incus start ceph"
  exit 1
fi

# Asegurar privileged mode
echo "[CHECK] Verificando privileged mode..."
PRIV=$(sudo incus config get ceph security.privileged 2>/dev/null || echo "false")
if [ "$PRIV" != "true" ]; then
  echo "Habilitando security.privileged=true en contenedor ceph..."
  sudo incus config set ceph security.privileged=true
  sudo incus restart ceph
  echo "Contenedor reiniciado. Esperando 10s..."
  sleep 10
fi

sudo incus exec ceph -- bash <<'CEPH_SETUP'

set -e

# Obtener IP dinámica del contenedor
MON_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')
echo "  IP del contenedor ceph: $MON_IP"

echo ""
echo "[1/10] Actualizando e instalando Ceph..."
apt update -qq > /dev/null 2>&1
apt install -y ceph ceph-mon ceph-osd ceph-mgr uuid-runtime -qq > /dev/null 2>&1
echo "  OK: $(ceph --version | head -1)"

echo "[2/10] Creando ceph.conf (auth=none bootstrap)..."
FSID=$(uuidgen)
mkdir -p /etc/ceph
cat > /etc/ceph/ceph.conf <<EOF
[global]
fsid = $FSID
mon host = $MON_IP
mon initial members = ceph1
public network = 10.100.0.0/24
cluster network = 10.100.0.0/24
auth cluster required = none
auth service required = none
auth client required = none
osd pool default size = 1
osd pool default min size = 1
osd pool default pg num = 32
osd pool default pgp num = 32
EOF
echo "  OK: fsid=$FSID"

echo "[3/10] Creando keyrings y monmap..."
ceph-authtool --create-keyring /etc/ceph/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *' > /dev/null 2>&1
ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin \
  --cap mon 'allow *' --cap osd 'allow *' --cap mgr 'allow *' --cap mds 'allow *' > /dev/null 2>&1
monmaptool --create --add ceph1 $MON_IP:6789 --fsid $FSID /etc/ceph/monmap > /dev/null 2>&1
echo "  OK"

echo "[4/10] Inicializando monitor..."
ceph-mon --mkfs -i ceph1 --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring > /dev/null 2>&1
chown -R ceph:ceph /var/lib/ceph/mon/ceph-ceph1/
cp /etc/ceph/ceph.mon.keyring /var/lib/ceph/mon/ceph-ceph1/keyring
chown ceph:ceph /var/lib/ceph/mon/ceph-ceph1/keyring
systemctl enable ceph-mon@ceph1 > /dev/null 2>&1
systemctl reset-failed ceph-mon@ceph1 2>/dev/null
systemctl start ceph-mon@ceph1
sleep 2
if ! systemctl is-active --quiet ceph-mon@ceph1; then
  echo "ERROR: ceph-mon no se inició."
  journalctl -u ceph-mon@ceph1 --no-pager | tail -15
  exit 1
fi
echo "  OK: monitor activo ($MON_IP:6789)"

echo "[5/10] Importando keyring admin y mgr..."
ceph auth import -i /etc/ceph/ceph.client.admin.keyring > /dev/null 2>&1
mkdir -p /var/lib/ceph/mgr/ceph-ceph1
ceph auth get-or-create mgr.ceph1 mon 'allow profile mgr' \
  -o /var/lib/ceph/mgr/ceph-ceph1/keyring > /dev/null 2>&1
chown -R ceph:ceph /var/lib/ceph/mgr/
systemctl enable ceph-mgr@ceph1 > /dev/null 2>&1
systemctl reset-failed ceph-mgr@ceph1 2>/dev/null
systemctl start ceph-mgr@ceph1
sleep 2
if ! systemctl is-active --quiet ceph-mgr@ceph1; then
  echo "ERROR: ceph-mgr no se inició."
  exit 1
fi
echo "  OK: manager activo"

echo "[6/10] Creando OSD BlueStore (archivo 5GB)..."
OSD_IMAGE=/var/lib/ceph/osd.img
OSD_ID=$(ceph osd create)
OSD_UUID=$(uuidgen)
mkdir -p /var/lib/ceph/osd/ceph-${OSD_ID}
chown ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}

dd if=/dev/zero of=$OSD_IMAGE bs=1M count=5120 status=progress 2>&1
chown ceph:ceph $OSD_IMAGE

echo "  Preparando OSD ${OSD_ID} con ceph-osd --mkfs..."
ln -sf $OSD_IMAGE /var/lib/ceph/osd/ceph-${OSD_ID}/block
chown -h ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}/block

ceph-osd --mkfs -i $OSD_ID --osd-uuid $OSD_UUID --conf /etc/ceph/ceph.conf \
  --osd-data /var/lib/ceph/osd/ceph-${OSD_ID} \
  --no-mon-config \
  --setuser ceph --setgroup ceph 2>&1
chown -R ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}

# Crear keyring del OSD
ceph auth get-or-create osd.${OSD_ID} mon 'allow profile osd' osd 'allow *' \
  -o /var/lib/ceph/osd/ceph-${OSD_ID}/keyring > /dev/null 2>&1
chown ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}/keyring

systemctl enable ceph-osd@${OSD_ID} > /dev/null 2>&1
systemctl reset-failed ceph-osd@${OSD_ID} 2>/dev/null
systemctl start ceph-osd@${OSD_ID}
sleep 3
if ! systemctl is-active --quiet ceph-osd@${OSD_ID}; then
  echo "ERROR: ceph-osd@${OSD_ID} no se inició."
  journalctl -u ceph-osd@${OSD_ID} --no-pager | tail -15
  exit 1
fi
echo "  OK: OSD $OSD_ID activo (file-backed)"

echo "[7/10] Creando pool reservas-pool..."
ceph osd pool create reservas-pool 32 > /dev/null 2>&1
echo "  OK: pool creado"

echo "[8/10] Creando keyring client.reservas..."
ceph auth get-or-create client.reservas \
  mon 'allow r' osd 'allow rw pool=reservas-pool' \
  -o /etc/ceph/ceph.client.reservas.keyring > /dev/null 2>&1
echo "  OK: client keyring creado"

echo "[9/10] Activando Cephx..."
# Reemplazar auth=none por auth=cephx (eliminar líneas duplicadas)
sed -i '/^auth cluster required/d' /etc/ceph/ceph.conf
sed -i '/^auth service required/d' /etc/ceph/ceph.conf
sed -i '/^auth client required/d' /etc/ceph/ceph.conf
cat >> /etc/ceph/ceph.conf <<CEPHX
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
CEPHX
# Copiar keyring del mon a su datadir (necesario con cephx)
cp /etc/ceph/ceph.mon.keyring /var/lib/ceph/mon/ceph-ceph1/keyring
chown ceph:ceph /var/lib/ceph/mon/ceph-ceph1/keyring
systemctl reset-failed ceph-mon@ceph1 2>/dev/null
systemctl restart ceph-mon@ceph1
sleep 2
if ! systemctl is-active --quiet ceph-mon@ceph1; then
  echo "ERROR: ceph-mon no se reinició con cephx."
  journalctl -u ceph-mon@ceph1 --no-pager | tail -15
  exit 1
fi
systemctl reset-failed ceph-mgr@ceph1 2>/dev/null
systemctl restart ceph-mgr@ceph1
sleep 1
systemctl reset-failed ceph-osd@${OSD_ID} 2>/dev/null
systemctl restart ceph-osd@${OSD_ID} 2>/dev/null || true
sleep 2
echo "  OK: Cephx activado"

echo "[10/10] Verificación final..."
echo ""
ceph -s
echo ""
echo "  OSDs:"
ceph osd tree
echo "  Pools:"
ceph osd pool ls detail

CEPH_SETUP

echo ""
echo "  Para probar desde api/core:"
echo "    sudo bash scripts/setup-ceph-client.sh"
echo ""
