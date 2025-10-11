variable "region" {
  description = "AWS region where the remote development resources live."
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "Optional named AWS CLI profile Terraform should use. Leave empty to use the default credential chain."
  type        = string
  default     = ""
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
  description = "List of EC2 instance ARNs remote developers are allowed to connect to and manage."
  type        = list(string)
  default     = []
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
