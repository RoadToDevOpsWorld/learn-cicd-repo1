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

variable "init_script" {
  type    = string
  default = "scripts/init.sh"
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

  provisioner "file" {
    source      = "scripts/harden.sh"
    destination = "/home/ubuntu/harden.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /home/ubuntu/harden.sh",
    ]
  }

  provisioner "shell" {
    script = var.init_script
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }

  post-processor "checksum" {
    checksum_types = ["md5", "sha512"]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
