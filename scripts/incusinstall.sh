#!/bin/bash

echo "Starting Incus installation on Debian..."

echo "Step 1: Updating package lists..."
sudo apt update
echo "Package lists updated."

echo "Step 2: Installing Incus using Zabbly's repository..."
echo "Creating /etc/apt/keyrings directory if it doesn't exist..."
sudo mkdir -p /etc/apt/keyrings/
echo "Directory created."

echo "Downloading Zabbly's GPG key..."
sudo curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
echo "GPG key downloaded."

echo "Adding Zabbly's stable repository..."
sudo sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc

EOF'
echo "Repository added."

echo "Updating package lists again..."
sudo apt-get update
echo "Package lists updated."

echo "Installing Incus, Incus client, and UI..."
sudo apt-get install -y incus incus-client incus-ui-canonical openvswitch-switch ovn-central ovn-host
echo "Incus installed."

echo "Step 3: Initializing Incus with minimal setup..."
sudo incus admin init --minimal
echo "Incus initialized."

echo "Step 4: Disabling Incus auto-start..."
sudo systemctl disable incus
echo "Incus auto-start disabled."

echo "Incus installation completed successfully."

# Ensure setup-lab.sh has execute permissions and run it
sudo chmod +x scripts/setup-lab.sh
bash scripts/setup-lab.sh