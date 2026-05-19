#!/bin/bash

echo "=========================================="
echo "Creating persistent volumes"

set -e  # Exit on any error

echo "[1/5] Creating postgres-d volume"
sudo incus storage volume create default postgres-data
echo "OK: postgres-d volume created"

echo "[2/5] Creating prometheus volume"
sudo incus storage volume create default prometheus-data
echo "OK: prometheus volume created"

echo "[3/5] Creating grafana volume"
sudo incus storage volume create default grafana-data
echo "OK: grafana volume created"

echo "[4/5] Creating ceph-data volume"
sudo incus storage volume create default ceph-data
echo "OK: ceph-data volume created"

echo "[5/5] Creating app-data volume"
sudo incus storage volume create default app-data
echo "OK: app-data volume created"

echo "All volumes created"