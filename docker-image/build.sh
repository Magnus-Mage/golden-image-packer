#!/bin/bash

# Build script for Packer OpenStack image
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Packer OpenStack Build Script ===${NC}"

# Check if packer is installed
if ! command -v packer &> /dev/null; then
    echo -e "${RED}Error: Packer is not installed or not in PATH${NC}"
    exit 1
fi

# Check OpenStack credentials
if [ -z "$OS_AUTH_URL" ] || [ -z "$OS_USERNAME" ] || [ -z "$OS_PASSWORD" ]; then
    echo -e "${RED}Error: OpenStack credentials not set${NC}"
    echo "Please source your OpenStack RC file or set environment variables:"
    echo "  OS_AUTH_URL, OS_USERNAME, OS_PASSWORD, OS_PROJECT_NAME"
    exit 1
fi

# Check if variables file exists
if [ ! -f "variables.pkrvars.hcl" ]; then
    echo -e "${RED}Error: variables.pkrvars.hcl not found${NC}"
    echo "Please create variables.pkrvars.hcl with your OpenStack settings"
    exit 1
fi

# Validate template syntax
echo -e "${YELLOW}Step 1: Validating Packer template...${NC}"
packer validate -var-file="variables.pkrvars.hcl" ubuntu-dev.pkr.hcl
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Template validation passed${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi

# Format template (optional)
echo -e "${YELLOW}Step 2: Formatting template...${NC}"
packer fmt ubuntu-dev.pkr.hcl

# Initialize Packer (download plugins)
echo -e "${YELLOW}Step 3: Initializing Packer plugins...${NC}"
packer init ubuntu-dev.pkr.hcl
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Plugin initialization completed${NC}"
else
    echo -e "${RED}✗ Plugin initialization failed${NC}"
    exit 1
fi

# Inspect template (optional - shows what will be built)
echo -e "${YELLOW}Step 4: Inspecting template...${NC}"
packer inspect -var-file="variables.pkrvars.hcl" ubuntu-dev.pkr.hcl

# Build the image
echo -e "${YELLOW}Step 5: Building image...${NC}"
echo "This may take 10-20 minutes depending on your OpenStack environment"

# Add timestamp to build
export PKR_VAR_image_name="ubuntu-dev-$(date +%Y%m%d-%H%M%S)"

packer build -var-file="variables.pkrvars.hcl" ubuntu-dev.pkr.hcl

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image build completed successfully!${NC}"
    
    # Show build artifacts
    if [ -f "manifest.json" ]; then
        echo -e "${YELLOW}Build artifacts:${NC}"
        cat manifest.json | jq '.builds[] | {name: .name, artifact_id: .artifact_id, build_time: .end_time}'
    fi
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run tests: ./test-image.sh"
    echo "2. Launch instance: openstack server create --image $PKR_VAR_image_name ..."
    
else
    echo -e "${RED}✗ Image build failed${NC}"
    exit 1
fi
