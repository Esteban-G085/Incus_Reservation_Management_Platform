#!/bin/bash

echo "=========================================="
echo "Starting creation of Incus profiles..."

echo "[1/6] Creating ctl profile..."
sudo incus profile create ctl
sudo incus profile set ctl limits.cpu=1 limits.memory=512MiB
sudo incus profile device add ctl root disk pool=default path=/
echo "OK: ctl profile created"

echo "[2/6] Creating api profile..."
sudo incus profile create api
sudo incus profile set api limits.cpu=2 limits.memory=1024MiB
sudo incus profile device add api root disk pool=default path=/
echo "OK: api profile created"

echo "[3/6] Creating core profile..."
sudo incus profile create core
sudo incus profile set core limits.cpu=2 limits.memory=1536MiB
sudo incus profile device add core root disk pool=default path=/
echo "OK: core profile created"

echo "[4/6] Creating db profile..."
sudo incus profile create db
sudo incus profile set db limits.cpu=4 limits.memory=4096MiB
sudo incus profile device add db root disk pool=default path=/
echo "OK: db profile created"

echo "[5/6] Creating mon profile..."
sudo incus profile create mon
sudo incus profile set mon limits.cpu=2 limits.memory=1024MiB
sudo incus profile device add mon root disk pool=default path=/
echo "OK: mon profile created"

echo "[6/6] Creating ceph profile..."
sudo incus profile create ceph
sudo incus profile set ceph limits.cpu=2 limits.memory=2048MiB
sudo incus profile device add ceph root disk pool=default path=/
echo "OK: ceph profile created"

echo "All profiles have been created successfully."
