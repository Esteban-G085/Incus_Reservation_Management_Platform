#!/bin/bash

echo "Starting Incus installation on Debian..."

# Fix 1: Convert all scripts from CRLF (Windows) to LF (Unix)
echo "Step 0: Converting scripts to Unix line endings..."
sudo apt-get install -y dos2unix
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dos2unix "$SCRIPT_DIR"/*.sh 2>/dev/null || true
echo "Line endings converted."

# Fix 2: Use apt-get instead of apt (apt doesn't support scripted use)
echo "Step 1: Updating package lists..."
sudo apt-get update
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

# Fix 3: Install only available packages; incus-ui-canonical and ovn-host
# may not exist in Zabbly's repo. We attempt to install them gracefully.
echo "Installing Incus and networking packages..."
# Core packages (these should always be available)
sudo apt-get install -y incus incus-client openvswitch-switch

# Try optional packages individually so missing ones don't block the install
echo "Attempting to install incus-ui-canonical (optional)..."
sudo apt-get install -y incus-ui-canonical 2>/dev/null || echo "WARNING: incus-ui-canonical not found, skipping. You can access the UI via 'incus webui' if supported."

echo "Attempting to install OVN packages (optional)..."
sudo apt-get install -y ovn-central 2>/dev/null || echo "WARNING: ovn-central not found, skipping."
sudo apt-get install -y ovn-host 2>/dev/null || echo "WARNING: ovn-host not found. Try 'apt-cache search ovn' to find the correct package name."

echo "Incus packages installed."

echo "Step 3: Initializing Incus with minimal setup..."
sudo incus admin init --minimal
echo "Incus initialized."

echo "Step 4: Disabling Incus auto-start..."
sudo systemctl disable incus
echo "Incus auto-start disabled."

echo "Incus installation completed successfully."

# Ensure setup-lab.sh has execute permissions and run it
sudo chmod +x "$SCRIPT_DIR/setup-lab.sh"
bash "$SCRIPT_DIR/setup-lab.sh"