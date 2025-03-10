terraform {
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

# Fetch the latest AMI owned by the user
data "aws_ami" "latest_owned_ami" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Lookup an existing subnet with a specific CIDR block
data "aws_subnet" "existing_subnet" {
  filter {
    name   = "cidr-block"
    values = ["172.31.0.0/20"]
  }
}

# Lookup an existing subnet with a specific CIDR block
data "aws_subnet" "existing_subnet1" {
  filter {
    name   = "cidr-block"
    values = ["172.31.16.0/20"]
  }
}


# Create a Launch Template
resource "aws_launch_template" "example" {
  name_prefix   = "example-launch-template"
  image_id      = data.aws_ami.latest_owned_ami.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.example.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "ExampleInstance"
    }
  }
}

# Create an Auto Scaling Group using the existing subnet
resource "aws_autoscaling_group" "example" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = [data.aws_subnet.existing_subnet.id]

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ExampleASG"
    propagate_at_launch = true
  }
}

# Security Group
resource "aws_security_group" "example" {
  name_prefix = "example-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2" {
  name_prefix = "ec2-sg"
}

resource "aws_vpc_security_group_ingress_rule" "example" {
  security_group_id = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.example.id
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}


resource "aws_lb" "alb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example.id]
  subnets            = [data.existing_subnet.existing_subnet.id, data.aws_subnet.existing_subnet1.id]

  enable_deletion_protection = true

  # access_logs {
  # bucket  = aws_s3_bucket.lb_logs.id
  #  prefix  = "test-lb"
  #  enabled = true
  # }

  tags = {
    Environment = "production"
  }
}