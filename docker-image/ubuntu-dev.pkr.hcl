packer {
  required_plugins {
    openstack = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

# Variables for flexibility
variable "source_image" {
  type        = string
  description = "Base image to use"
  default     = "ubuntu-22.04"  # Adjust based on your OpenStack images
}

variable "flavor" {
  type        = string
  description = "Instance flavor for building"
  default     = "m1.small"  # Adjust based on your available flavors
}

variable "network" {
  type        = string
  description = "Network UUID for the build instance"
  # You'll need to set this based on your openstack network list
}

variable "image_name" {
  type        = string
  description = "Name for the output image"
  default     = "ubuntu-dev-{{timestamp}}"
}

# OpenStack source configuration
source "openstack" "ubuntu" {
  image_name        = var.image_name
  source_image      = var.source_image
  flavor            = var.flavor
  networks          = [var.network]
  ssh_username      = "ubuntu"
  
  # Optional: Use floating IP if needed
  use_floating_ip   = true
  
  # Optional: Security groups
  security_groups   = ["default"]
  
  # Image metadata
  image_metadata = {
    os_type     = "linux"
    os_distro   = "ubuntu"
    description = "Ubuntu development image with Python, Docker, and Git"
  }
}

# Build configuration
build {
  name = "ubuntu-dev-build"
  sources = [
    "source.openstack.ubuntu"
  ]

  # Update system packages
  provisioner "shell" {
    inline = [
      "echo 'Starting system update...'",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget unzip"
    ]
  }

  # Install Git
  provisioner "shell" {
    inline = [
      "echo 'Installing Git...'",
      "sudo apt-get install -y git",
      "git --version"
    ]
  }

  # Install Python (latest stable)
  provisioner "shell" {
    inline = [
      "echo 'Installing Python...'",
      "sudo apt-get install -y python3 python3-pip python3-venv python3-dev",
      "sudo ln -sf /usr/bin/python3 /usr/bin/python",
      "python --version",
      "pip3 --version"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      "sudo apt-get install -y apt-transport-https ca-certificates gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu"
    ]
  }

  # Install additional development tools
  provisioner "shell" {
    inline = [
      "echo 'Installing additional development tools...'",
      "sudo apt-get install -y build-essential software-properties-common",
      "sudo apt-get install -y htop tree jq vim nano",
      "sudo apt-get install -y nodejs npm"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "history -c"
    ]
  }

  # Validation tests
  provisioner "shell" {
    inline = [
      "echo 'Running validation tests...'",
      "python --version",
      "pip3 --version",
      "git --version",
      "docker --version",
      "node --version",
      "npm --version"
    ]
  }

  # Generate manifest for tracking
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
  }
}
