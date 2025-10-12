#!/bin/bash

# Auto-shutdown script for development instances
# This script will automatically shut down the instance after the specified number of hours

# Install AWS CLI v2 if not present
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
fi

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Calculate shutdown time (current time + specified hours)
SHUTDOWN_HOURS=${shutdown_hours}
SHUTDOWN_TIME=$(date -d "+${SHUTDOWN_HOURS} hours" "+%Y-%m-%d %H:%M:%S")

echo "Instance will auto-shutdown at: $SHUTDOWN_TIME"

# Create a systemd service for auto-shutdown
cat > /etc/systemd/system/auto-shutdown.service << EOF
[Unit]
Description=Auto-shutdown service for development instance
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep $((SHUTDOWN_HOURS * 3600)) && aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION'
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable auto-shutdown.service
systemctl start auto-shutdown.service

# Log the shutdown schedule
echo "Auto-shutdown scheduled for $(date -d "+${SHUTDOWN_HOURS} hours")" >> /var/log/auto-shutdown.log

# Update system packages
yum update -y

# Install useful development tools
yum install -y git vim htop tree jq curl wget unzip

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install VS Code Server
VSCODE_VERSION="4.19.0"
wget https://github.com/coder/code-server/releases/download/v${VSCODE_VERSION}/code-server-${VSCODE_VERSION}-linux-amd64.tar.gz
tar -xzf code-server-${VSCODE_VERSION}-linux-amd64.tar.gz
mv code-server-${VSCODE_VERSION}-linux-amd64 /opt/code-server
ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server
rm code-server-${VSCODE_VERSION}-linux-amd64.tar.gz

# Create code-server service
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=VS Code Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
Environment=PASSWORD=dev123456
ExecStart=/usr/local/bin/code-server --bind-addr 0.0.0.0:8080 --auth password
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create development workspace
mkdir -p /home/ec2-user/workspace
chown -R ec2-user:ec2-user /home/ec2-user/workspace

# Set up GitHub SSH access
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Note: SSH keys will be loaded from 1Password during instance startup
# This is handled by the GitHub setup script

# Create Docker development environment
cat > /home/ec2-user/docker-compose.yml << 'EOF'
version: '3.8'
services:
  dev-environment:
    image: codercom/code-server:latest
    container_name: vscode-server
    ports:
      - "8080:8080"
    environment:
      - PASSWORD=dev123456
    volumes:
      - /home/ec2-user/workspace:/home/coder/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    command: --bind-addr 0.0.0.0:8080 --auth password
    restart: unless-stopped
    user: "1000:1000"
EOF

chown ec2-user:ec2-user /home/ec2-user/docker-compose.yml

# Set up GitHub SSH access
echo "Setting up GitHub SSH access..."
if [ -n "${github_ssh_private_key}" ] && [ "${github_ssh_private_key}" != "" ]; then
    # Install 1Password CLI if not present
    if ! command -v op >/dev/null 2>&1; then
        echo "Installing 1Password CLI..."
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | tee /etc/apt/sources.list.d/1password.list
        apt-get update
        apt-get install -y 1password-cli
    fi

    # Sign in to 1Password (this should already be done by the main script)
    OP_ACCOUNT="my.1password.com"
    if op account list >/dev/null 2>&1; then
        echo "Loading SSH keys from 1Password..."
        
        # Load private key
        if [ -n "${github_ssh_private_key}" ] && [ "${github_ssh_private_key}" != "" ]; then
            echo "Loading GitHub SSH private key..."
            op read "${github_ssh_private_key}" --account "$OP_ACCOUNT" > /home/ec2-user/.ssh/id_rsa
            chmod 600 /home/ec2-user/.ssh/id_rsa
            chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
        fi

        # Load public key
        if [ -n "${github_ssh_public_key}" ] && [ "${github_ssh_public_key}" != "" ]; then
            echo "Loading GitHub SSH public key..."
            op read "${github_ssh_public_key}" --account "$OP_ACCOUNT" > /home/ec2-user/.ssh/id_rsa.pub
            chmod 644 /home/ec2-user/.ssh/id_rsa.pub
            chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa.pub
        fi

        # Load and display fingerprint
        if [ -n "${github_ssh_fingerprint}" ] && [ "${github_ssh_fingerprint}" != "" ]; then
            echo "Loading GitHub SSH key fingerprint..."
            FINGERPRINT=$(op read "${github_ssh_fingerprint}" --account "$OP_ACCOUNT")
            echo "SSH Key Fingerprint: $FINGERPRINT"
        fi

        # Configure SSH for GitHub
        cat > /home/ec2-user/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

        chmod 600 /home/ec2-user/.ssh/config
        chown ec2-user:ec2-user /home/ec2-user/.ssh/config

        # Add GitHub to known hosts
        ssh-keyscan -H github.com >> /home/ec2-user/.ssh/known_hosts
        chmod 644 /home/ec2-user/.ssh/known_hosts
        chown ec2-user:ec2-user /home/ec2-user/.ssh/known_hosts

        # Configure Git
        if [ -n "${github_username}" ] && [ "${github_username}" != "" ]; then
            sudo -u ec2-user git config --global user.name "${github_username}"
        fi

        if [ -n "${github_email}" ] && [ "${github_email}" != "" ]; then
            sudo -u ec2-user git config --global user.email "${github_email}"
        fi

        # Configure Git to use SSH for GitHub
        sudo -u ec2-user git config --global url."git@github.com:".insteadOf "https://github.com/"

        # Test GitHub SSH connection
        echo "Testing GitHub SSH connection..."
        if sudo -u ec2-user ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
            echo "✅ GitHub SSH connection successful!"
        else
            echo "⚠️  GitHub SSH connection test failed. Please check your SSH keys."
            echo "You can test manually with: ssh -T git@github.com"
        fi

        # Create a helpful script for GitHub operations
        cat > /home/ec2-user/github-setup.sh << EOF
#!/bin/bash
# GitHub Setup Helper Script

echo "GitHub SSH Configuration:"
echo "========================="
echo "SSH Key: ~/.ssh/id_rsa"
echo "Config: ~/.ssh/config"
if [ -n "${github_ssh_fingerprint}" ] && [ "${github_ssh_fingerprint}" != "" ]; then
    echo "Fingerprint: $(op read "${github_ssh_fingerprint}" --account "my.1password.com")"
fi
echo ""
echo "Git Configuration:"
echo "=================="
git config --global --list | grep -E "(user\.name|user\.email|url\.git@github\.com)"
echo ""
echo "Test GitHub Connection:"
echo "======================="
ssh -T git@github.com
echo ""
echo "Clone a repository:"
echo "==================="
echo "git clone git@github.com:username/repository.git"
EOF

        chmod +x /home/ec2-user/github-setup.sh
        chown ec2-user:ec2-user /home/ec2-user/github-setup.sh

        echo "GitHub SSH setup completed!"
    else
        echo "Error: Not signed in to 1Password CLI"
    fi
else
    echo "No GitHub SSH keys configured. Skipping GitHub setup."
fi

# Start VS Code Server
systemctl daemon-reload
systemctl enable code-server.service
systemctl start code-server.service

# Create a welcome message
cat > /etc/motd << EOF
========================================
Development Instance - Auto-shutdown Enabled
========================================
Instance ID: $INSTANCE_ID
Region: $REGION
Auto-shutdown: $SHUTDOWN_TIME
========================================
VS Code Server: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080
Password: dev123456
========================================
GitHub SSH Access:
  Test connection: ssh -T git@github.com
  Clone repo: git clone git@github.com:username/repo.git
  Setup info: ./github-setup.sh
  Key fingerprint: $(op read "${github_ssh_fingerprint}" --account "my.1password.com" 2>/dev/null || echo "Not available")
========================================
Docker Commands:
  docker-compose up -d    # Start VS Code container
  docker-compose down     # Stop VS Code container
========================================
This instance will automatically shut down
in ${SHUTDOWN_HOURS} hours to save costs.
========================================
EOF