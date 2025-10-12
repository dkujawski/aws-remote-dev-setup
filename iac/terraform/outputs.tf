output "remote_dev_user_name" {
  description = "The IAM user created for remote developers."
  value       = aws_iam_user.remote_dev.name
}

output "remote_dev_group_name" {
  description = "The IAM group that aggregates remote developer permissions."
  value       = aws_iam_group.remote_dev.name
}

output "remote_dev_policy_arn" {
  description = "ARN of the policy granting access to remote development instances."
  value       = aws_iam_policy.remote_dev.arn
}

# EC2 Instance Outputs
output "dev_instances" {
  description = "Information about the created development instances."
  value = {
    for idx, instance in aws_instance.dev_instances : "instance-${idx + 1}" => {
      id         = instance.id
      arn        = instance.arn
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      state      = instance.instance_state
      type       = instance.instance_type
      name       = "${var.instance_name_prefix}-${idx + 1}"
    }
  }
}

output "dev_instance_ids" {
  description = "List of development instance IDs."
  value       = aws_instance.dev_instances[*].id
}

output "dev_instance_arns" {
  description = "List of development instance ARNs."
  value       = aws_instance.dev_instances[*].arn
}

output "session_manager_connection_commands" {
  description = "AWS CLI commands to connect to instances via Session Manager."
  value = [
    for idx, instance in aws_instance.dev_instances : 
    "aws ssm start-session --target ${instance.id} --region ${var.region}"
  ]
}

output "vscode_server_urls" {
  description = "VS Code Server URLs for web-based development."
  value = [
    for instance in aws_instance.dev_instances :
    "http://${instance.public_ip}:8080"
  ]
}

output "vscode_server_password" {
  description = "VS Code Server password for authentication."
  value       = "dev123456"
  sensitive   = false
}

output "github_ssh_setup" {
  description = "GitHub SSH setup information and test commands."
  value = {
    ssh_key_location = "~/.ssh/id_rsa"
    ssh_config = "~/.ssh/config"
    test_command = "ssh -T git@github.com"
    clone_example = "git clone git@github.com:username/repository.git"
    setup_script = "./github-setup.sh"
    fingerprint_source = "op://Private/vscode-remote-aws-dev-session/fingerprint"
  }
}

output "github_ssh_key" {
  description = "GitHub SSH key information managed by Terraform."
  value = {
    key_id = github_user_ssh_key.dev_key.id
    title = github_user_ssh_key.dev_key.title
    username = data.github_user.current.login
    url = "https://github.com/settings/keys"
  }
}

output "cost_optimization_info" {
  description = "Information about cost optimization features enabled."
  value = {
    spot_instances_enabled = var.enable_spot_instances
    instance_type          = var.instance_type
    auto_shutdown_hours    = var.auto_shutdown_hours
    estimated_hourly_cost  = var.enable_spot_instances ? "~$0.005-0.01 (Spot pricing)" : "~$0.01-0.02 (On-demand)"
  }
}
