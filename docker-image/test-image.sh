#!/bin/bash

# Test script for validating the built image
set -e

echo "=== Image Testing Script ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 PASSED${NC}"
    else
        echo -e "${RED}✗ $1 FAILED${NC}"
        exit 1
    fi
}

# Get image ID from manifest (if available)
if [ -f "manifest.json" ]; then
    IMAGE_ID=$(jq -r '.builds[0].custom_data.image_id // .builds[0].artifact_id' manifest.json 2>/dev/null || echo "")
    echo "Testing image: $IMAGE_ID"
fi

# Variables (adjust these for your environment)
IMAGE_NAME=${1:-"ubuntu-dev-v1.0"}
FLAVOR=${2:-"m1.small"}
NETWORK=${3:-"your-network-uuid"}
KEY_NAME=${4:-"your-keypair-name"}  # SSH key pair name in OpenStack

echo "=== Launching test instance ==="
echo "Image: $IMAGE_NAME"
echo "Flavor: $FLAVOR"
echo "Network: $NETWORK"

# Launch instance from the built image
INSTANCE_ID=$(openstack server create \
    --image "$IMAGE_NAME" \
    --flavor "$FLAVOR" \
    --network "$NETWORK" \
    --key-name "$KEY_NAME" \
    --wait \
    "packer-test-$(date +%s)" \
    -f value -c id)

print_status "Instance creation"

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to be active
echo "Waiting for instance to be active..."
openstack server show "$INSTANCE_ID" --format value --column status

# Get instance IP
INSTANCE_IP=$(openstack server show "$INSTANCE_ID" -f value -c addresses | cut -d'=' -f2)
echo "Instance IP: $INSTANCE_IP"

# Wait a bit more for SSH to be ready
echo "Waiting for SSH to be ready..."
sleep 30

# Function to run SSH commands
run_ssh_test() {
    local command="$1"
    local description="$2"
    
    echo "Testing: $description"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@"$INSTANCE_IP" "$command"
    print_status "$description"
}

# Run tests via SSH
echo "=== Running remote tests ==="

run_ssh_test "python --version" "Python installation"
run_ssh_test "pip3 --version" "pip installation"
run_ssh_test "git --version" "Git installation"
run_ssh_test "docker --version" "Docker installation"
run_ssh_test "node --version" "Node.js installation"
run_ssh_test "which python && which git && which docker" "All binaries in PATH"

# Test Docker functionality
run_ssh_test "sudo docker run --rm hello-world" "Docker functionality"

# Test Python functionality
run_ssh_test "python -c 'import sys; print(sys.version)'" "Python execution"

# Test git functionality
run_ssh_test "git config --global user.name 'Test User' && git config --global user.email 'test@example.com' && git init /tmp/test-repo" "Git functionality"

echo -e "${GREEN}=== All tests passed! ===${NC}"

# Cleanup
echo "=== Cleaning up test instance ==="
openstack server delete "$INSTANCE_ID" --wait
print_status "Instance cleanup"

echo -e "${GREEN}Image validation completed successfully!${NC}"
