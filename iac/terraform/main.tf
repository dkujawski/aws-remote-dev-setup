terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "github" {
  token = var.github_token
}

locals {
  # Use dynamically created instances if no specific ARNs provided
  dev_instance_arns = length(var.dev_instance_arns) > 0 ? var.dev_instance_arns : [
    for instance in aws_instance.dev_instances : "arn:aws:ec2:${var.region}:*:instance/${instance.id}"
  ]
  session_manager_document_arns = var.session_manager_document_arns
}

resource "aws_iam_group" "remote_dev" {
  name = var.iam_group_name
}

resource "aws_iam_user" "remote_dev" {
  name = var.remote_dev_user_name
  force_destroy = var.force_destroy_user
}

resource "aws_iam_group_membership" "remote_dev" {
  name = "${aws_iam_group.remote_dev.name}-membership"
  users = [aws_iam_user.remote_dev.name]
  group = aws_iam_group.remote_dev.name
}

resource "aws_iam_policy" "remote_dev" {
  name        = var.iam_policy_name
  description = "Permissions for remote developers to manage their dedicated instances via Session Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "SessionManagerDescribe"
          Effect = "Allow"
          Action = [
            "ssm:DescribeInstanceInformation",
            "ssm:DescribeSessions",
            "ssm:GetConnectionStatus"
          ]
          Resource = ["*"]
        },
        {
          Sid    = "EC2Describe"
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeTags"
          ]
          Resource = ["*"]
        }
      ],
      length(local.dev_instance_arns) > 0 ? [
        {
          Sid    = "SessionManagerInstances"
          Effect = "Allow"
          Action = [
            "ssm:StartSession",
            "ssm:TerminateSession",
            "ssm:ResumeSession"
          ]
          Resource = local.dev_instance_arns
        },
        {
          Sid    = "SessionManagerDocuments"
          Effect = "Allow"
          Action = [
            "ssm:StartSession",
            "ssm:ResumeSession"
          ]
          Resource = local.session_manager_document_arns
        },
        {
          Sid    = "InstanceLifecycle"
          Effect = "Allow"
          Action = [
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ec2:RebootInstances"
          ]
          Resource = local.dev_instance_arns
        }
      ] : []
    )
  })
}

resource "aws_iam_group_policy_attachment" "remote_dev" {
  group      = aws_iam_group.remote_dev.name
  policy_arn = aws_iam_policy.remote_dev.arn
}

# GitHub SSH Key Management
data "github_user" "current" {
  username = var.github_username
}

# Load public key from 1Password for GitHub SSH key
data "external" "github_public_key" {
  program = ["bash", "-c", "echo '{\"key\":\"'$(op read '${var.github_ssh_public_key}' --account 'my.1password.com')'\"}'"]
}

resource "github_user_ssh_key" "dev_key" {
  title = "AWS Remote Dev - ${var.instance_name_prefix}"
  key   = data.external.github_public_key.result.key
}

# Data sources for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for development instances
resource "aws_security_group" "dev_instances" {
  name_prefix = "${var.instance_name_prefix}-sg"
  description = "Security group for development instances"

  # HTTP access for VS Code Server
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "VS Code Server"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name_prefix}-security-group"
  }
}

# IAM role for EC2 instances to work with Systems Manager
resource "aws_iam_role" "dev_instance_role" {
  name = "${var.instance_name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for Systems Manager
resource "aws_iam_role_policy_attachment" "dev_instance_ssm" {
  role       = aws_iam_role.dev_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "dev_instance_profile" {
  name = "${var.instance_name_prefix}-instance-profile"
  role = aws_iam_role.dev_instance_role.name
}

# User data script for auto-shutdown and GitHub setup
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    shutdown_hours = var.auto_shutdown_hours
    github_ssh_private_key = var.github_ssh_private_key
    github_ssh_public_key = var.github_ssh_public_key
    github_ssh_fingerprint = var.github_ssh_fingerprint
    github_username = var.github_username
    github_email = var.github_email
  }))
}

# EC2 instances
resource "aws_instance" "dev_instances" {
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.dev_instance_profile.name
  vpc_security_group_ids = [aws_security_group.dev_instances.id]
  user_data              = local.user_data

  # Spot instance configuration for maximum cost savings
  spot_price = var.enable_spot_instances ? (var.spot_max_price != "" ? var.spot_max_price : null) : null
  spot_type  = var.enable_spot_instances ? "one-time" : null

  # Instance market options for Spot instances
  dynamic "instance_market_options" {
    for_each = var.enable_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type = "one-time"
      }
    }
  }

  # No persistent storage - use ephemeral storage only
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8  # Minimal size for cost savings
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "${var.instance_name_prefix}-${count.index + 1}"
    Environment = "development"
    AutoShutdown = "true"
    CreatedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}
