#!/bin/bash
# setup-lab.sh - High-level Incus Lab Setup Script
# This script automates the initial Incus infrastructure setup for the microservices lab.

set -e  # Exit on any error

echo "=========================================="
echo "  MICROSERVICES LAB SETUP"
echo "=========================================="
echo ""

# Step 1: Ensure network.sh has execute permissions and run it
echo "[1/6] Creating OVN network for the lab..."
sudo chmod +x scripts/network.sh
bash scripts/network.sh
echo ""

# Step 2: Ensure profiles.sh has execute permissions and run it
echo "[2/6] Setting up Incus profiles..."
sudo chmod +x scripts/profiles.sh
bash scripts/profiles.sh
echo "Profiles created successfully"
echo ""

# Step 3: Ensure volumes.sh has execute permissions and run it
echo "[3/6] Creating persistent storage volumes..."
sudo chmod +x scripts/volumes.sh
bash scripts/volumes.sh
echo ""

# Step 4: Ensure containers.sh has execute permissions and run it
echo "[4/6] Launching and configuring containers..."
sudo chmod +x scripts/containers.sh
bash scripts/containers.sh
echo ""

# Step 5: Infrastructure validation
echo ""
echo "[5/6]Running post-configuration validation..."
sudo chmod +x scripts/validate.sh
bash scripts/validate.sh
echo ""

# TODO: Step 6 - Configure services
echo "# Configure services inside containers using Ansible"
echo "# Commands:"
echo "#   - Ensure Ansible is installed on host or ctl"
echo "#   - Create inventory file with container IPs"
echo "#   - Run ansible-playbook playbook.yml"
echo ""

echo "=========================================="
echo "✅ INFRASTRUCTURE DEPLOYMENT COMPLETED"
echo "=========================================="