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
