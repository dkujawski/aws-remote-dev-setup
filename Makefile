# AWS Remote Development Setup Makefile

# 1Password configuration
OP_ACCOUNT := my.1password.com
OP_EMAIL := dave.kujawski@gmail.com
OP_USER_ID := WIDMKOA2DFEFJP5UP2TE7GRCRA
TF_TOKEN_SECRET := "op://Private/tf_cloud_javisrike/credential"

# AWS configuration
AWS_PROFILE := badassdave

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: check-aws
check-aws: ## Check if AWS CLI is configured with the badassdave profile
	@if ! command -v aws >/dev/null 2>&1; then \
		echo "Error: AWS CLI is not installed."; \
		echo "Please install it from: https://aws.amazon.com/cli/"; \
		exit 1; \
	fi
	@if ! aws sts get-caller-identity --profile $(AWS_PROFILE) >/dev/null 2>&1; then \
		echo "Error: AWS profile '$(AWS_PROFILE)' is not configured or credentials are invalid."; \
		echo "Please configure your AWS credentials for profile '$(AWS_PROFILE)'"; \
		echo "Run 'aws configure --profile $(AWS_PROFILE)' or check your credentials."; \
		exit 1; \
	fi
	@echo "AWS profile '$(AWS_PROFILE)' is configured and valid"

.PHONY: check-op
check-op: ## Check if 1Password CLI is installed and signed in
	@if ! command -v op >/dev/null 2>&1; then \
		echo "Error: 1Password CLI (op) is not installed."; \
		echo "Please install it from: https://1password.com/downloads/command-line/"; \
		exit 1; \
	fi
	@if ! op account list >/dev/null 2>&1; then \
		echo "Error: Not signed in to 1Password CLI."; \
		echo "Run 'make op-signin' to authenticate."; \
		exit 1; \
	fi

.PHONY: op-signin
op-signin: ## Sign in to 1Password CLI
	@echo "Signing in to 1Password CLI..."
	@op account add --address $(OP_ACCOUNT) --email $(OP_EMAIL) --userid $(OP_USER_ID) || true
	@op signin --account $(OP_ACCOUNT) --raw >/dev/null 2>&1 || op signin --account $(OP_ACCOUNT)

.PHONY: load-tf-token
load-tf-token: check-op ## Load Terraform Cloud token from 1Password into environment
	@echo "Loading Terraform Cloud token from 1Password..."
	@export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	echo "TF_TOKEN_app_terraform_io loaded successfully" && \
	echo "To use this token in your current shell, run:" && \
	echo "export TF_TOKEN_app_terraform_io=\$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT))"

.PHONY: load-github-token
load-github-token: check-op ## Load GitHub API token from 1Password into environment
	@echo "Loading GitHub API token from 1Password..."
	@export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	echo "GITHUB_TOKEN loaded successfully" && \
	echo "To use this token in your current shell, run:" && \
	echo "export GITHUB_TOKEN=\$$(op read \"op://Private/github-iac-ssh-key/credential\" --account $(OP_ACCOUNT))"

.PHONY: check-prereqs
check-prereqs: check-aws check-op ## Check all prerequisites (AWS profile and 1Password CLI)
	@echo "All prerequisites are satisfied"

.PHONY: tf-init
tf-init: check-prereqs ## Initialize Terraform with AWS profile and 1Password tokens
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform init

.PHONY: tf-plan
tf-plan: check-prereqs ## Run terraform plan with AWS profile and 1Password tokens
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform plan

.PHONY: tf-apply
tf-apply: check-prereqs ## Run terraform apply with AWS profile and 1Password tokens
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform apply

.PHONY: tf-destroy
tf-destroy: check-prereqs ## Run terraform destroy with AWS profile and 1Password tokens
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform destroy

.PHONY: setup
setup: check-prereqs ## Complete setup: verify AWS profile and 1Password CLI
	@echo "Setup complete! AWS profile '$(AWS_PROFILE)' and 1Password CLI are ready."
	@echo "You can now run 'make tf-init', 'make tf-plan', or 'make tf-apply'"

.PHONY: tf-outputs
tf-outputs: check-prereqs ## Show Terraform outputs including VS Code Server URLs
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform output

.PHONY: vscode-urls
vscode-urls: check-prereqs ## Show VS Code Server URLs and connection info
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	echo "VS Code Server URLs:" && \
	terraform output -raw vscode_server_urls | tr -d '[]"' | tr ',' '\n' | sed 's/^/  /' && \
	echo "" && \
	echo "Password: $$(terraform output -raw vscode_server_password)" && \
	echo "" && \
	echo "Session Manager Commands:" && \
	terraform output -raw session_manager_connection_commands | tr -d '[]"' | tr ',' '\n' | sed 's/^/  /'

.PHONY: status
status: check-prereqs ## Check status of all provisioned resources across AWS and GitHub
	@echo "=========================================="
	@echo "🔍 Checking Infrastructure Status"
	@echo "=========================================="
	@echo ""
	@echo "📋 Loading tokens from 1Password..."
	@export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	echo "✅ Tokens loaded successfully"
	@echo ""
	@echo "🏗️  Terraform State Status:"
	@echo "=========================="
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform show -json | jq -r '.values.root_module.resources[] | select(.type != null) | "\(.type): \(.name) - \(.values.tags.Name // .values.name // "N/A")"' 2>/dev/null || echo "  No resources found or Terraform not initialized"
	@echo ""
	@echo "☁️  AWS Resources Status:"
	@echo "========================"
	@echo "  🔍 Checking EC2 instances..."
	@aws ec2 describe-instances --profile $(AWS_PROFILE) --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null || echo "  ❌ Failed to query EC2 instances"
	@echo ""
	@echo "  🔍 Checking IAM resources..."
	@aws iam get-user --user-name $$(cd iac/terraform && export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && export AWS_PROFILE=$(AWS_PROFILE) && terraform output -raw remote_dev_user_name 2>/dev/null) --profile $(AWS_PROFILE) --query 'User.UserName' --output text 2>/dev/null && echo "  ✅ IAM User exists" || echo "  ❌ IAM User not found"
	@echo ""
	@echo "  🔍 Checking Security Groups..."
	@aws ec2 describe-security-groups --profile $(AWS_PROFILE) --query 'SecurityGroups[?contains(GroupName, `dev-instance`)].{Name:GroupName,Id:GroupId,Description:Description}' --output table 2>/dev/null || echo "  ❌ Failed to query Security Groups"
	@echo ""
	@echo "🐙 GitHub Resources Status:"
	@echo "=========================="
	@echo "  🔍 Checking GitHub SSH keys..."
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform output github_ssh_key 2>/dev/null | jq -r '"  Key ID: " + .key_id + "\n  Title: " + .title + "\n  Username: " + .username + "\n  URL: " + .url' 2>/dev/null || echo "  ❌ GitHub SSH key not found in Terraform state"
	@echo ""
	@echo "  🔍 Verifying GitHub API access..."
	@curl -s -H "Authorization: token $$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT))" https://api.github.com/user | jq -r '"  Username: " + .login + "\n  Name: " + (.name // "Not set") + "\n  Email: " + (.email // "Not set")' 2>/dev/null || echo "  ❌ Failed to access GitHub API"
	@echo ""
	@echo "🌐 VS Code Server Status:"
	@echo "========================"
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform output vscode_server_urls 2>/dev/null | jq -r '.[]' | while read url; do \
		echo "  🔍 Testing VS Code Server: $$url"; \
		curl -s -o /dev/null -w "  Status: %{http_code} - %{time_total}s\n" "$$url" 2>/dev/null || echo "  ❌ VS Code Server not responding"; \
	done
	@echo ""
	@echo "📊 Cost Information:"
	@echo "==================="
	@cd iac/terraform && \
	export TF_TOKEN_app_terraform_io=$$(op read $(TF_TOKEN_SECRET) --account $(OP_ACCOUNT)) && \
	export GITHUB_TOKEN=$$(op read "op://Private/github-iac-ssh-key/credential" --account $(OP_ACCOUNT)) && \
	export AWS_PROFILE=$(AWS_PROFILE) && \
	terraform output cost_optimization_info 2>/dev/null | jq -r '"  Spot Instances: " + (.spot_instances_enabled | tostring) + "\n  Instance Type: " + .instance_type + "\n  Auto-shutdown: " + (.auto_shutdown_hours | tostring) + " hours\n  Estimated Cost: " + .estimated_hourly_cost' 2>/dev/null || echo "  ❌ Cost information not available"
	@echo ""
	@echo "=========================================="
	@echo "✅ Status check completed!"
	@echo "=========================================="