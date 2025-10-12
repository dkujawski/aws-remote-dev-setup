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

# EC2 Instance Configuration
variable "instance_count" {
  description = "Number of development instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type for development instances"
  type        = string
  default     = "t3.micro"  # Most budget-friendly general purpose instance
}

variable "instance_name_prefix" {
  description = "Prefix for instance names"
  type        = string
  default     = "dev-instance"
}

variable "auto_shutdown_hours" {
  description = "Number of hours after which instances should auto-shutdown (max 24)"
  type        = number
  default     = 24
  validation {
    condition     = var.auto_shutdown_hours > 0 && var.auto_shutdown_hours <= 24
    error_message = "Auto shutdown hours must be between 1 and 24."
  }
}

variable "enable_spot_instances" {
  description = "Use Spot instances for maximum cost savings (may be interrupted)"
  type        = bool
  default     = true
}

variable "spot_max_price" {
  description = "Maximum price per hour for Spot instances (leave empty for current Spot price)"
  type        = string
  default     = ""
}

# GitHub Configuration
variable "github_ssh_private_key" {
  description = "SSH private key for GitHub access (stored in 1Password)"
  type        = string
  default     = "op://Private/vscode-remote-aws-dev-session/private key"
}

variable "github_ssh_public_key" {
  description = "SSH public key for GitHub access (stored in 1Password)"
  type        = string
  default     = "op://Private/vscode-remote-aws-dev-session/public key"
}

variable "github_ssh_fingerprint" {
  description = "SSH key fingerprint for GitHub access (stored in 1Password)"
  type        = string
  default     = "op://Private/vscode-remote-aws-dev-session/fingerprint"
}

variable "github_username" {
  description = "GitHub username for Git configuration and SSH key management"
  type        = string
  default     = "dkujawski"
}

variable "github_email" {
  description = "GitHub email for Git configuration"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub fine-grained API token for managing SSH keys (stored in 1Password)"
  type        = string
  default     = "op://Private/github-iac-ssh-key/credential"
  sensitive   = true
}
