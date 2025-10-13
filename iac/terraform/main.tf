terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "Javisrike"

    workspaces {
      name = "aws-remote-dev-setup"
    }
  }
}

provider "aws" {
  region                  = var.region
  profile                 = var.profile
  shared_credentials_files = ["~/.aws/credentials"]
}

locals {
  session_manager_document_arns = var.session_manager_document_arns
  create_instance_profile       = length(var.dev_instances) > 0
}

resource "aws_iam_group" "remote_dev" {
  name = var.iam_group_name
}

resource "aws_iam_user" "remote_dev" {
  name          = var.remote_dev_user_name
  force_destroy = var.force_destroy_user
}

resource "aws_iam_group_membership" "remote_dev" {
  name  = "${aws_iam_group.remote_dev.name}-membership"
  users = [aws_iam_user.remote_dev.name]
  group = aws_iam_group.remote_dev.name
}

data "aws_iam_policy_document" "remote_dev_instance_assume_role" {
  count = local.create_instance_profile ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "remote_dev_instance" {
  count = local.create_instance_profile ? 1 : 0

  name               = "${var.remote_dev_user_name}-instance"
  assume_role_policy = data.aws_iam_policy_document.remote_dev_instance_assume_role[count.index].json
  tags               = var.default_dev_instance_tags
}

resource "aws_iam_role_policy_attachment" "remote_dev_instance_ssm" {
  count = local.create_instance_profile ? 1 : 0

  role       = aws_iam_role.remote_dev_instance[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "remote_dev" {
  count = local.create_instance_profile ? 1 : 0

  name = "${var.remote_dev_user_name}-instance"
  role = aws_iam_role.remote_dev_instance[count.index].name
}

locals {
  default_instance_profile_name = try(one(aws_iam_instance_profile.remote_dev).name, null)
}

resource "aws_instance" "remote_dev" {
  for_each = var.dev_instances

  ami                    = each.value.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = try(each.value.security_group_ids, null)
  iam_instance_profile   = lookup(each.value, "iam_instance_profile", local.default_instance_profile_name)
  key_name               = lookup(each.value, "key_name", null)

  associate_public_ip_address = lookup(each.value, "associate_public_ip", null)

  root_block_device {
    volume_size = lookup(each.value, "volume_size", 50)
    volume_type = lookup(each.value, "volume_type", "gp3")
    encrypted   = lookup(each.value, "encrypted", true)
    kms_key_id  = lookup(each.value, "kms_key_id", null)
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    var.default_dev_instance_tags,
    lookup(each.value, "tags", {}),
    {
      "Name" = each.key
    }
  )
}

locals {
  managed_dev_instance_arns = [for instance in aws_instance.remote_dev : instance.arn]
  all_dev_instance_arns     = concat(var.dev_instance_arns, local.managed_dev_instance_arns)
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
      length(local.all_dev_instance_arns) > 0 ? [
        {
          Sid    = "SessionManagerInstances"
          Effect = "Allow"
          Action = [
            "ssm:StartSession",
            "ssm:TerminateSession",
            "ssm:ResumeSession"
          ]
          Resource = local.all_dev_instance_arns
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
          Resource = local.all_dev_instance_arns
        }
      ] : []
    )
  })
}

resource "aws_iam_group_policy_attachment" "remote_dev" {
  group      = aws_iam_group.remote_dev.name
  policy_arn = aws_iam_policy.remote_dev.arn
}
