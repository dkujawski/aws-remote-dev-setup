variable "region" {
  description = "AWS region where the remote development resources live."
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "Name of the AWS CLI profile (stored in ~/.aws/credentials) Terraform should use."
  type        = string
}

variable "remote_dev_user_name" {
  description = "Name of the IAM user provisioned for remote developers."
  type        = string
  default     = "remote-dev"
}

variable "iam_group_name" {
  description = "Name of the IAM group that aggregates remote developer permissions."
  type        = string
  default     = "remote-dev-access"
}

variable "iam_policy_name" {
  description = "Name for the IAM policy that encapsulates remote developer permissions."
  type        = string
  default     = "remote-dev-access"
}

variable "dev_instance_arns" {
  description = "List of EC2 instance ARNs remote developers are allowed to connect to and manage in addition to the instances this configuration creates."
  type        = list(string)
  default     = []
}

variable "dev_instances" {
  description = "Map describing the remote development EC2 instances to create."
  type = map(object({
    ami_id                = string
    instance_type         = string
    subnet_id             = string
    security_group_ids    = optional(list(string))
    iam_instance_profile  = optional(string)
    key_name              = optional(string)
    associate_public_ip   = optional(bool)
    volume_size           = optional(number)
    volume_type           = optional(string)
    encrypted             = optional(bool)
    kms_key_id            = optional(string)
    tags                  = optional(map(string))
  }))
  default = {}
}

variable "default_dev_instance_tags" {
  description = "Base tags applied to every remote development EC2 instance."
  type        = map(string)
  default = {
    "ManagedBy" = "terraform"
    "Purpose"   = "remote-development"
  }
}

variable "session_manager_document_arns" {
  description = "List of Session Manager document ARNs remote developers are permitted to use."
  type        = list(string)
  default = [
    "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
    "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSession"
  ]
}

variable "force_destroy_user" {
  description = "When true Terraform will remove the IAM user even if it still has access keys or MFA devices."
  type        = bool
  default     = false
}

variable "posts_lambda_artifact_bucket_name" {
  description = "Name of the S3 bucket that stores posts Lambda deployment artifacts."
  type        = string
}

variable "github_deploy_role_names" {
  description = "GitHub deploy role names by environment that require posts artifact upload permissions."
  type = object({
    dev  = string
    prod = string
  })
}
