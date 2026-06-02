#!/bin/bash

echo "=========================================="
echo "Starting network configuration..."

set -e

echo "[1/5] Checking incusbr0 state as managed..."
MANAGED=$(sudo incus network show incusbr0 | grep -E '^\s*managed:' | awk '{print $2}')

if [ "$MANAGED" = "false" ]; then
    echo "incusbr0 bridge exists but it isn't managed by Incus"
    echo "Deleting incusbr0..."
    sudo ip link set incusbr0 down
    sudo ip link delete incusbr0
    
    echo "Recreating incusbr0 as a managed bridge by Incus..."
    sudo incus network create incusbr0 \
        ipv4.address=10.158.133.1/24 \
        ipv4.nat=true \
        ipv6.address=none
    echo "OK: incusbr0 has been recreated"
else
    echo "OK: incusbr0 is a managed net by now"
fi

echo "[2/5] Setting up Open vSwitch for OVN..."
sudo ovs-vsctl set open_vswitch . \
  external_ids:ovn-remote=unix:/run/ovn/ovnsb_db.sock \
  external_ids:ovn-encap-type=geneve \
  external_ids:ovn-encap-ip=127.0.0.1
echo "OK: Open vSwitch configured"

echo "[3/5] Linking Incus to OVN..."
sudo incus config set network.ovn.northbound_connection unix:/run/ovn/ovnnb_db.sock
echo "OK: Incus linked to OVN"

echo "[4/5] Preparing incusbr0 as uplink..."
BRIDGE_IP=$(sudo incus network show incusbr0 | grep "ipv4.address" | awk '{print $2}' | cut -d'/' -f1)
BASE=$(echo $BRIDGE_IP | cut -d'.' -f1-3)
DHCP_RANGES="${BASE}.2-${BASE}.200"
OVN_RANGES="${BASE}.201-${BASE}.250"

sudo incus network set incusbr0 \
  ipv4.dhcp.ranges=$DHCP_RANGES \
  ipv4.ovn.ranges=$OVN_RANGES
sudo incus network set incusbr0 ipv4.routes=10.100.0.0/24
echo "OK: incusbr0 prepared as uplink"

echo "[5/5] Creating OVN lab-net for microservices lab..."
sudo incus network create lab-net \
  --type=ovn \
  network=incusbr0 \
  ipv4.address=10.100.0.1/24 \
  ipv4.nat=true
echo "OK: OVN 'lab-net' created"

echo "All networks configurated"
