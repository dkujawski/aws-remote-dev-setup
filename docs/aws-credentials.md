# AWS credential configuration guide

Remote developers need valid AWS credentials in order to authenticate against the IAM resources that Terraform provisions in this repository. This guide walks through three common approaches for configuring the AWS CLI and SDK credential chain so that developers can choose the option that best matches their security and compliance requirements.

## 1. Configure a named AWS CLI profile

Use a named profile when you distribute long-lived access keys for the remote development IAM user. Profiles isolate credentials, making it easy to switch between environments.

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

The CLI stores the profile in `~/.aws/credentials` and `~/.aws/config`. Developers can reference it via the `AWS_PROFILE` environment variable or by using the `--profile` flag with individual CLI commands.

## 2. Use AWS IAM Identity Center (SSO)

If your organization relies on AWS IAM Identity Center (formerly AWS SSO), you can map the remote development IAM group to an account assignment and federate access without managing long-lived keys.

1. Configure an assignment in IAM Identity Center that maps your developers to the AWS account where the Terraform resources were applied.
2. Grant the assignment permission to assume a role that has the `remote-dev-access` policy attached.
3. Have developers log in with the AWS CLI:
   ```bash
   aws sso login --profile remote-dev-sso
   ```
4. Update the profile configuration in `~/.aws/config` so that it references the SSO start URL, region, and role name. A minimal example:
   ```ini
   [profile remote-dev-sso]
   sso_start_url = https://my-sso-portal.awsapps.com/start
   sso_region = us-east-1
   sso_account_id = 123456789012
   sso_role_name = RemoteDevAccess
   region = us-east-1
   ```

Once logged in, developers can run commands with `AWS_PROFILE=remote-dev-sso` and the CLI will automatically refresh temporary credentials as needed.

## 3. Leverage credential helpers (aws-vault)

For teams that still use IAM access keys but want to avoid storing them on disk, [aws-vault](https://github.com/99designs/aws-vault) can encrypt credentials and vend short-lived sessions.

1. Install `aws-vault` using your platform's package manager.
2. Add the access keys to the secure keychain:
   ```bash
   aws-vault add remote-dev
   ```
3. Execute commands within a temporary session:
   ```bash
   aws-vault exec remote-dev -- aws ssm start-session --target i-0123456789abcdef0
   ```

The helper rotates credentials regularly and protects them using the underlying OS keychain, reducing the risk of key exfiltration.

## Environment variables for automation

Automation tools running in CI/CD pipelines or containerized environments can authenticate using environment variables. Set the following variables before invoking the AWS CLI or Terraform:

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="<secret>"
export AWS_SESSION_TOKEN="<optional session token>"
export AWS_DEFAULT_REGION="us-east-1"
```

Use short-lived session tokens (for example, generated via IAM roles or STS) whenever possible. Never commit secrets to source control.

## Verifying access

After configuring credentials with any of the methods above, run these quick checks:

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
