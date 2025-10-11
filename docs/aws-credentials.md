# AWS credential configuration guide

Remote developers need valid AWS credentials in order to authenticate against the IAM resources that Terraform provisions in this repository. The Terraform configuration is opinionated: it always loads credentials from the shared AWS CLI credentials file (`~/.aws/credentials`) using a named profile. The steps below describe how administrators and developers should configure that profile.

## Configure a named AWS CLI profile

Use a named profile when you distribute long-lived access keys for the remote development IAM user. Profiles isolate credentials, making it easy to switch between environments and match the expectations baked into Terraform.

1. Install the [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
2. Collect the `Access key ID` and `Secret access key` for the IAM user created by Terraform.
3. Run the interactive configuration command and provide the credentials when prompted:
   ```bash
   aws configure --profile remote-dev
   ```
4. Confirm that the credentials work by describing the allowed EC2 instances:
   ```bash
   AWS_PROFILE=remote-dev aws ec2 describe-instances --instance-ids i-0123456789abcdef0
   ```

The CLI stores the profile in `~/.aws/credentials` and `~/.aws/config`. Developers can reference it via the `AWS_PROFILE` environment variable or by using the `--profile` flag with individual CLI commands. Terraform also relies on this profile—configure the `profile` variable in `terraform.tfvars` so that it matches the name you specified above.

## Verifying access

After configuring the profile, run these quick checks:

```bash
# Confirm the caller identity matches the remote dev IAM user or role
aws sts get-caller-identity

# Start a Session Manager session against an approved instance
aws ssm start-session --target i-0123456789abcdef0
```

If you receive an access denied error, verify that the EC2 instance ARN is included in `dev_instance_arns` and that the Session Manager agent is installed and running on the instance.

## Troubleshooting tips

- **"The provided instance is not managed by AWS Systems Manager":** Ensure the instance has the SSM agent installed and an IAM instance profile with the `AmazonSSMManagedInstanceCore` policy.
- **"AccessDeniedException" when starting a session:** Confirm that the IAM policy includes the instance ARN and the Session Manager document ARNs (`AWS-StartSSHSession` or `AWS-StartPortForwardingSession`).
- **Credentials appear to work locally but Terraform fails:** Terraform may be using a different profile. Set `AWS_PROFILE` or configure the `profile` variable in [`iac/terraform/variables.tf`](../iac/terraform/variables.tf).
- **Sessions disconnect unexpectedly:** Session Manager terminates idle connections after 20 minutes by default. Adjust the Session Manager preferences if longer sessions are required.
