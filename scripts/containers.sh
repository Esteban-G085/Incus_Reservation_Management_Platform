#!/bin/bash

echo "=========================================="
echo "Starting containers creation and configuration"

set -e  # Exit on any error

# Launch ctl
echo "[1/6] Launching ctl container"
if ! sudo incus info ctl >/dev/null 2>&1; then
    sudo incus launch images:debian/13 ctl -p ctl -p default -n lab-net
    echo "OK: ctl launched"
else
    echo "OK: ctl already exists, skipping"
fi

# Launch api with app-data volume
echo "[2/6] Launching app-data container"
if ! sudo incus info api >/dev/null 2>&1; then
    sudo incus launch images:debian/13 api -p api -p default -n lab-net
    if sudo incus storage volume show default app-data >/dev/null 2>&1; then
        sudo incus config device add api app-volume disk pool=default source=app-data path=/app/data
        echo "OK: api launched and volume attached"
    else
        echo "ALERT: Volume app-data not found, api launched without volume"
    fi
else
    echo "OK: api already exists, skipping"
fi

# Launch core with app-data volume
echo "[3/6] Launching core container"
if ! sudo incus info core >/dev/null 2>&1; then
    sudo incus launch images:debian/13 core -p core -p default -n lab-net
    if sudo incus storage volume show default app-data >/dev/null 2>&1; then
        sudo incus config device add core app-volume disk pool=default source=app-data path=/app/data
        echo "OK: core launched and volume attached"
    else
        echo "ALERT: Volume app-data not found, core launched without volume"
    fi
else
    echo "OK: core already exists, skipping"
fi

# Launch db with postgres-data volume
echo "[4/6] Launching db container"
if ! sudo incus info db >/dev/null 2>&1; then
    sudo incus launch images:debian/13 db -p db -p default -n lab-net
    if sudo incus storage volume show default postgres-data >/dev/null 2>&1; then
        sudo incus config device add db postgres-volume disk pool=default source=postgres-data path=/var/lib/postgresql
        echo "OK: db launched and volume attached"
    else
        echo "ALERT: Volume postgres-data not found, db launched without volume"
    fi
else
    echo "OK: db already exists, skipping"
fi

# Launch mon with prometheus-data and grafana-data volumes
echo "[5/6] Launching mon container"
if ! sudo incus info mon >/dev/null 2>&1; then
    sudo incus launch images:debian/13 mon -p mon -p default -n lab-net
    if sudo incus storage volume show default prometheus-data >/dev/null 2>&1; then
        sudo incus config device add mon prometheus-volume disk pool=default source=prometheus-data path=/prometheus
    else
        echo "ALERT: Volume prometheus-data not found"
    fi
    if sudo incus storage volume show default grafana-data >/dev/null 2>&1; then
        sudo incus config device add mon grafana-volume disk pool=default source=grafana-data path=/var/lib/grafana
    else
        echo "ALERT: Volume grafana-data not found"
    fi
    echo "OK: mon launched and volumes attached"
else
    echo "OK: mon already exists, skipping"
fi

# Launch ceph with ceph-data volume
echo "[6/6] Launching ceph container"
if ! sudo incus info ceph >/dev/null 2>&1; then
    sudo incus launch images:debian/13 ceph -p ceph -p default -n lab-net
    if sudo incus storage volume show default ceph-data >/dev/null 2>&1; then
        sudo incus config device add ceph ceph-volume disk pool=default source=ceph-data path=/var/lib/ceph
        echo "OK: ceph launched and volume attached"
    else
        echo "ALERT: Volume ceph-data not found, ceph launched without volume"
    fi
else
    echo "OK: ceph already exists, skipping"
fi

echo "All containers launched and configured"
