terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

locals {
  dev_instance_arns           = var.dev_instance_arns
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
