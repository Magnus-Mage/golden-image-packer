#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Add the HashiCorp GPG key
echo "Adding HashiCorp GPG key..."
wget -O - https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add the HashiCorp repo to the sources list
echo "Adding HashiCorp repository..."
CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# Update and install Packer
echo "Updating package list and installing Packer..."
sudo apt update && sudo apt install -y packer

echo "Packer installation completed!"

