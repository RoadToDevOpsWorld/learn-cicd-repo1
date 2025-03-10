packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

variable "ami_name" {
  type    = string
  default = "app-image"
}

variable "playbook_file" {
  type    = string
  default = "src/templates/packer/ansible/playbook.yml"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "vpc_region" {
  type    = string
  default = "us-east-1"
}

source "amazon-ebs" "app-infra" {
  associate_public_ip_address = true
  ami_groups                  = []
  ami_name                    = "${var.ami_name}-${local.timestamp}"
  instance_type               = var.instance_type
  region                      = var.vpc_region
  ssh_pty                     = "true"
  ssh_timeout                 = "120m"
  ssh_username                = "ubuntu"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 60
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  name = "standard"

  sources = [
    "source.amazon-ebs.app-infra"
  ]

  # Install Ansible
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y software-properties-common",
      "sudo apt-add-repository -y ppa:ansible/ansible",
      "sudo apt-get update",
      "sudo apt-get install -y ansible"
    ]
  }

  # Copy Ansible playbook files to the instance
  provisioner "file" {
    source      = "./ansible/"
    destination = "/tmp/ansible"
  }

  # Run Ansible playbook
  provisioner "ansible-local" {
    playbook_file = var.playbook_file
    # playbook_dir  = "src/templates/packer/ansible"
    command       = "PYTHONUNBUFFERED=1 ansible-playbook"
    extra_arguments = [
      "--extra-vars", "\"ansible_python_interpreter=/usr/bin/python3\"",
      "-v"
    ]
  }

  post-processor "checksum" {
    checksum_types = ["md5", "sha512"]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}