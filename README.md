# AWS Remote Development Setup

This repository contains infrastructure-as-code assets and documentation that help teams provision and operate a secure remote development environment on AWS. The Terraform configuration in [`iac/terraform`](iac/terraform) creates a dedicated IAM user and policy that limits developers to connecting to pre-approved EC2 instances through AWS Systems Manager Session Manager. Additional documentation under [`docs`](docs) explains how to configure local AWS credentials so that developers can authenticate with this IAM user using a named profile stored in `~/.aws/credentials`.

## Repository structure

| Path | Description |
| --- | --- |
| [`docs/aws-credentials.md`](docs/aws-credentials.md) | Guides developers through configuring their local AWS credentials and profiles for remote development. |
| [`iac/terraform`](iac/terraform) | Terraform configuration that provisions the IAM user, group, and permissions required for remote development. |

## Getting started with Terraform

1. Install [Terraform](https://developer.hashicorp.com/terraform/downloads) version 1.4 or newer and configure an administrator [AWS CLI profile](docs/aws-credentials.md) in `~/.aws/credentials`. Terraform is hard-coded to use this credential source.
2. Copy [`iac/terraform/terraform.tfvars.example`](iac/terraform/terraform.tfvars.example) to `iac/terraform/terraform.tfvars` and update the values for your environment (region, profile name, and the EC2 development instances you want Terraform to create and/or authorize).
3. Initialize the Terraform working directory:
   ```bash
   cd iac/terraform
   terraform init
   ```
4. Review the planned changes:
   ```bash
   terraform plan
   ```
5. Apply the configuration once you are satisfied with the plan:
   ```bash
   terraform apply
   ```
6. Share the IAM user credentials with your developers and direct them to the [AWS credential configuration guide](docs/aws-credentials.md) so they can connect securely.

### Provisioning development instances

The Terraform configuration can now create the EC2 instances that remote developers connect to. Declare one or more instances in the `dev_instances` map inside `terraform.tfvars`. Each entry lets you control the AMI, instance type, networking configuration, and tags. Terraform automatically adds these instances to the IAM policy so that the remote development user can connect to them with AWS Systems Manager Session Manager.

If you already have EC2 instances that should remain outside Terraform's control, list their ARNs in the optional `dev_instance_arns` variable. They will be included in the access policy alongside the managed instances.

> **Note:** The Terraform configuration only grants access to the EC2 instance ARNs you specify. Make sure the instances are managed by AWS Systems Manager and have the SSM agent installed so that Session Manager connections succeed.

## Contributing

Contributions that improve the remote development workflow or documentation are welcome! Please open an issue before submitting a pull request so we can discuss substantial changes.
