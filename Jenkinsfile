//final ver
pipeline {
    agent any
    // setting the environment like aws creds, ssh key path
    environment {
        AWS_CREDS = credentials('aws-credentials')
        TF_VAR_region = 'us-east-1'
        TF_VAR_bucket_name = 'sonarqube-terraform-state-12'
        SSH_KEY_PATH = "${WORKSPACE}/.ssh/sonarqube-key.pem"
        // virtual env path
        VENV_PATH = "${WORKSPACE}/venv"
    }

    stages {
        // terraform repo checkout
        stage('Git Checkout - Terraform Repo') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://github.com/mukeshdevelp/infra-sonarqube-modular.git',
                        credentialsId: 'github-user-password'
                    ]]
                ])
            }
        }

        // Commented out - working fine, no need to run every time
        /*
        stage('AWS CLI Test & Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    //simple init stage
                    sh '''
                        
                        aws s3 ls
                        # Set WORKSPACE variable for Terraform
                        export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                        terraform init --reconfigure
                        echo "terraform initialized"
                    '''
                }
            }
        }
        */

        stage('Terraform Formatting') {
            steps {
                // formatting terraform code
                sh '''
                    export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                    terraform fmt && echo "formatted terraform code"
                '''
            }
        }

        // Commented out - working fine, no need to run every time
        /*
        stage('Terraform Validate') {
            steps {
                // validating terraform code
                sh '''
                    export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                    terraform validate && echo "validated terraform code"
                '''
            }
        }
        */

        // Commented out - working fine, no need to run every time
        /*
        stage('Terraform Plan') {
            steps {
                // planning terraform code
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                        terraform plan && echo "planning terraform code"
                    '''
                }
            }
        }
        */

        stage('Terraform Apply') {
            steps {
                // applying terraform code , and changing the ssh key permissions
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                        terraform apply --auto-approve
                        
                        # SSH key is in workspace - ensure it exists and has correct permissions
                        if [ ! -f $WORKSPACE/.ssh/sonarqube-key.pem ]; then
                            echo "ERROR: SSH key not found at $WORKSPACE/.ssh/sonarqube-key.pem"
                            exit 1
                        fi
                        
                        chmod 400 $WORKSPACE/.ssh/sonarqube-key.pem

                        echo "infra created"
                    '''
                }
            }
        }
        // storing the private ips of the bastion host
        stage('Store Private IPs') {
            steps {
                sh '''
                ./store_ip.sh
                
                # Save ips.env to a safe location that won't be overwritten by Ansible repo checkout
                # Create a backup directory for pipeline artifacts
                mkdir -p ${WORKSPACE}/.pipeline-artifacts
                if [ -f "${WORKSPACE}/ips.env" ]; then
                    cp "${WORKSPACE}/ips.env" "${WORKSPACE}/.pipeline-artifacts/ips.env"
                    echo "SUCCESS: ips.env backed up to .pipeline-artifacts/ips.env"
                else
                    echo "WARNING: ips.env not found after store_ip.sh"
                fi
                '''
            }
        }
        // fixinbng the ssh key permissions
        stage('ssh key permissions'){
            steps {
                sh '''
                    set -e
                    
                    # Fix SSH key permissions
                    chmod 400 $SSH_KEY_PATH
                    
                    # Source the IPs from the stored environment file using POSIX-compliant . command
                    if [ -f "${WORKSPACE}/ips.env" ]; then
                        # Use . instead of source (POSIX-compliant, works in both sh and bash)
                        . "${WORKSPACE}/ips.env"
                        echo "Bastion IP from stored file: ${BASTION_PUBLIC_IP}"
                        echo "Bastion DNS from stored file: ${BASTION_PUBLIC_DNS}"
                    else
                        # Fallback: Get bastion IP/DNS directly from Terraform output
                        BASTION_PUBLIC_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
                        BASTION_PUBLIC_DNS=$(terraform output -raw bastion_public_dns 2>/dev/null || echo "")
                        echo "Bastion IP from Terraform output: ${BASTION_PUBLIC_IP}"
                        echo "Bastion DNS from Terraform output: ${BASTION_PUBLIC_DNS}"
                    fi
                    
                    # Prefer DNS over IP (DNS is more stable if IP changes)
                    if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                        BASTION_HOST="$BASTION_PUBLIC_DNS"
                        echo "Using Bastion DNS: ${BASTION_HOST}"
                    elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                        BASTION_HOST="$BASTION_PUBLIC_IP"
                        echo "Using Bastion IP: ${BASTION_HOST}"
                    else
                        echo "ERROR: Bastion public IP/DNS not available"
                        exit 1
                    fi
                    
                    # Create .ssh directory on bastion host if it doesn't exist
                    echo "Setting up .ssh directory on bastion host at ${BASTION_HOST}"
                    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ubuntu@${BASTION_HOST} "
                        mkdir -p /home/ubuntu/.ssh
                        chmod 700 /home/ubuntu/.ssh
                        ls -ld /home/ubuntu/.ssh
                    " || {
                        echo "ERROR: Failed to create .ssh directory on bastion"
                        exit 1
                    }
                    
                    # Verify .ssh directory exists and has correct permissions
                    echo "Verifying .ssh directory setup..."
                    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ubuntu@${BASTION_HOST} "
                        if [ ! -d /home/ubuntu/.ssh ]; then
                            echo 'ERROR: .ssh directory does not exist'
                            exit 1
                        fi
                        if [ \"\$(stat -c %a /home/ubuntu/.ssh)\" != \"700\" ]; then
                            echo 'Fixing .ssh directory permissions...'
                            chmod 700 /home/ubuntu/.ssh
                        fi
                        echo 'SUCCESS: .ssh directory is ready'
                    "
                    
                    # SSH key is already on bastion host - no need to copy it
                    # Fix permissions on bastion host (key already exists)
                    echo "Verifying SSH key exists and fixing permissions on bastion host..."
                    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ubuntu@${BASTION_HOST} "
                        if [ ! -f /home/ubuntu/.ssh/sonarqube-key.pem ]; then
                            echo 'WARNING: SSH key not found at /home/ubuntu/.ssh/sonarqube-key.pem'
                            echo 'Please ensure the key is already on the bastion host'
                        else
                            chmod 400 /home/ubuntu/.ssh/sonarqube-key.pem
                            ls -l /home/ubuntu/.ssh/sonarqube-key.pem
                            echo 'SUCCESS: SSH key permissions verified'
                        fi
                    "
                    
                    echo "SUCCESS: SSH key copied to bastion host"
                '''
            }
        }
        // ansible repo checkout
        stage('Git Checkout - Ansible Repo') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://github.com/mukeshdevelp/ansible-assignment-5-v2.git',
                        credentialsId: 'github-user-password'
                    ]]
                ])
            }
        }

        // setting up the virtual environment and installing the ansible dependencies
            stage('Setup Virtualenv & Install Ansible dependencies') {
                steps {
                    sh '''
                        
                        python3 -m venv $VENV_PATH
                        . $VENV_PATH/bin/activate
                        echo "Virtual environment activated at $VIRTUAL_ENV"
                        
                        pip install --upgrade pip
                        pip install boto3 botocore ansible

                        # Ansible collection
                        ansible-galaxy collection install amazon.aws
                        
                        echo "Dependencies installed successfully"
                    '''
        }
    }       

        // testing the bastion connectivity
        stage('Test Bastion Connectivity') {
            steps {
                sh '''
                    set -e
                    
                    # Get bastion host information
                    if [ -f "${WORKSPACE}/ips.env" ]; then
                        . "${WORKSPACE}/ips.env"
                    fi
                    
                    # Prefer DNS over IP
                    if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                        BASTION_HOST="$BASTION_PUBLIC_DNS"
                    elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                        BASTION_HOST="$BASTION_PUBLIC_IP"
                    else
                        BASTION_PUBLIC_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
                        BASTION_PUBLIC_DNS=$(terraform output -raw bastion_public_dns 2>/dev/null || echo "")
                        if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                            BASTION_HOST="$BASTION_PUBLIC_DNS"
                        elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                            BASTION_HOST="$BASTION_PUBLIC_IP"
                        else
                            echo "ERROR: Bastion host not found!"
                            exit 1
                        fi
                    fi
                    
                    SSH_KEY="$SSH_KEY_PATH"
                    chmod 400 "$SSH_KEY"
                    
                    echo "=== Testing Bastion Host Connectivity ==="
                    echo "Bastion Host: $BASTION_HOST"
                    
                    # Test SSH to bastion
                    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$BASTION_HOST "echo 'Bastion is reachable'"; then
                        echo "SUCCESS: Bastion host is reachable"
                    else
                        echo "ERROR: Cannot connect to bastion host"
                        echo "This may indicate security group or network issues"
                        exit 1
                    fi
                    
                    echo "Note: Private instance connectivity will be tested from bastion in next stage"
                '''
            }
        }
        
        // installing the sonarqube from the bastion host
        stage('Install SonarQube from Bastion Host') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        #!/bin/bash
                        set -e  # Exit immediately on error
                        
                        # Get bastion host DNS from stored file (created in "Store Private IPs" stage)
                        # Note: After Ansible repo checkout, workspace is overwritten, so we use the backup location
                        # The ips.env file is backed up to .pipeline-artifacts/ips.env before Ansible checkout
                        IPS_ENV_FILE="${WORKSPACE}/.pipeline-artifacts/ips.env"
                        if [ -f "$IPS_ENV_FILE" ]; then
                            echo "Loading bastion DNS from backed up ips.env file..."
                            . "$IPS_ENV_FILE"
                        elif [ -f "${WORKSPACE}/ips.env" ]; then
                            echo "Loading bastion DNS from ips.env file (if still exists)..."
                            . "${WORKSPACE}/ips.env"
                        else
                            echo "ERROR: ips.env file not found in backup location or workspace"
                            echo "Expected location: $IPS_ENV_FILE"
                            echo "This means 'Store Private IPs' stage may have failed or backup failed"
                            exit 1
                        fi
                        
                        # Use DNS (preferred over IP as it's more stable)
                        BASTION_HOST="${BASTION_PUBLIC_DNS}"
                        
                        # Verify bastion host DNS is set
                        if [ -z "$BASTION_HOST" ] || [ "$BASTION_HOST" = "" ] || [ "$BASTION_HOST" = "N/A" ]; then
                            echo "ERROR: Bastion host DNS not found!"
                            echo "BASTION_PUBLIC_DNS: ${BASTION_PUBLIC_DNS:-NOT SET}"
                            exit 1
                        fi
                        
                        echo "Using bastion host DNS: $BASTION_HOST"
                        
                        # Use SSH_KEY_PATH from environment (already defined in pipeline)
                        SSH_KEY="$SSH_KEY_PATH"
                        if [ ! -f "$SSH_KEY" ]; then
                            echo "ERROR: SSH key not found at $SSH_KEY"
                            exit 1
                        fi
                        
                        echo "=========================================="
                        echo "Installing SonarQube from Bastion Host"
                        echo "=========================================="
                        echo "Bastion Host: $BASTION_HOST"
                        echo "Strategy: SSH into bastion, run Ansible from there"
                        echo ""
                        
                        # Step 1: Copy Ansible playbook files to bastion
                        echo "=== Step 1: Copying Ansible files to bastion ==="
                        
                        # Define Ansible playbook file paths (from workspace root after Git checkout)
                        ANSIBLE_PLAYBOOK_DIR="${WORKSPACE}"
                        ANSIBLE_SITE_YML="${ANSIBLE_PLAYBOOK_DIR}/site.yml"
                        ANSIBLE_AWS_EC2_YML="${ANSIBLE_PLAYBOOK_DIR}/aws_ec2.yml"
                        ANSIBLE_CFG="${ANSIBLE_PLAYBOOK_DIR}/ansible.cfg"
                        ANSIBLE_ROLES_DIR="${ANSIBLE_PLAYBOOK_DIR}/roles"
                        BASTION_PLAYBOOK_DIR="~/ansible-playbook"
                        
                        # Verify files exist before copying
                        if [ ! -f "$ANSIBLE_SITE_YML" ] || [ ! -f "$ANSIBLE_AWS_EC2_YML" ] || [ ! -f "$ANSIBLE_CFG" ] || [ ! -d "$ANSIBLE_ROLES_DIR" ]; then
                            echo "ERROR: Required Ansible files not found in workspace"
                            echo "  Expected: $ANSIBLE_SITE_YML"
                            echo "  Expected: $ANSIBLE_AWS_EC2_YML"
                            echo "  Expected: $ANSIBLE_CFG"
                            echo "  Expected: $ANSIBLE_ROLES_DIR"
                            exit 1
                        fi
                        
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST "mkdir -p $BASTION_PLAYBOOK_DIR"
                        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
                            "$ANSIBLE_SITE_YML" \
                            "$ANSIBLE_AWS_EC2_YML" \
                            "$ANSIBLE_CFG" \
                            "$ANSIBLE_ROLES_DIR" \
                            ubuntu@$BASTION_HOST:$BASTION_PLAYBOOK_DIR/
                        echo "Files copied successfully"
                        echo ""
                        
                        # Step 2: Install Ansible and dependencies on bastion
                        echo "=== Step 2: Setting up Ansible on bastion ==="
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST << 'BASTION_SETUP'
                            set -e
                            # Unset WORKSPACE to ensure Ansible uses bastion's SSH key path, not Jenkins workspace
                            unset WORKSPACE
                            cd ~/ansible-playbook
                            
                            # Check if Ansible is already installed
                            if ! command -v ansible-playbook &> /dev/null; then
                                echo "Installing Ansible and dependencies..."
                                sudo apt-get update -qq
                                sudo apt-get install -y python3-pip python3-venv git curl wget awscli
                                python3 -m pip install --user --upgrade pip
                                python3 -m pip install --user ansible boto3 botocore
                                
                                # Add pip user bin to PATH permanently in .bashrc
                                if ! grep -q "\$HOME/.local/bin" ~/.bashrc; then
                                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                                fi
                                
                                # Add pip user bin to PATH for this session
                                export PATH="$HOME/.local/bin:$PATH"
                                
                                # Install Ansible AWS collection
                                echo "Installing Ansible AWS collection..."
                                ansible-galaxy collection install amazon.aws
                                
                                # Verify installations
                                echo "Verifying installed tools..."
                                curl --version || echo "curl check"
                                wget --version || echo "wget check"
                                aws --version || echo "awscli check"
                                echo "Ansible location: \$(which ansible || echo ~/.local/bin/ansible)"
                            else
                                echo "Ansible already installed"
                                # Ensure PATH is in .bashrc
                                if ! grep -q "\$HOME/.local/bin" ~/.bashrc; then
                                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                                fi
                                export PATH="$HOME/.local/bin:$PATH"
                                
                                # Ensure other tools are installed
                                sudo apt-get update -qq
                                sudo apt-get install -y curl wget awscli 2>/dev/null || echo "Tools may already be installed"
                            fi
                            
                            # Verify Ansible installation
                            ansible --version || {
                                echo "Ansible verification failed, reinstalling..."
                                python3 -m pip install --user ansible boto3 botocore
                                export PATH="$HOME/.local/bin:$PATH"
                            }
                            export PATH="$HOME/.local/bin:$PATH"
                            ansible --version
                            
                            # Verify AWS collection
                            ansible-galaxy collection list | grep amazon.aws || ansible-galaxy collection install amazon.aws
                            
                            # Final verification - ensure ansible binaries exist
                            if [ ! -f "\$HOME/.local/bin/ansible" ] || [ ! -f "\$HOME/.local/bin/ansible-playbook" ] || [ ! -f "\$HOME/.local/bin/ansible-inventory" ]; then
                                echo "ERROR: Ansible binaries not found after installation"
                                echo "Checking installation location..."
                                find \$HOME -name ansible -type f 2>/dev/null || echo "Ansible not found"
                                exit 1
                            fi
                            echo "SUCCESS: Ansible installation verified"
                            ls -la \$HOME/.local/bin/ansible*
BASTION_SETUP
                        echo "Ansible setup completed"
                        echo ""
                        
                        # Verify Ansible is accessible before proceeding
                        echo "=== Verifying Ansible installation before running playbook ==="
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST "
                            export PATH=\"/home/ubuntu/.local/bin:\$PATH\"
                            if [ ! -f /home/ubuntu/.local/bin/ansible-inventory ]; then
                                echo 'ERROR: Ansible not found after setup. Reinstalling...'
                                python3 -m pip install --user ansible boto3 botocore
                                export PATH=\"/home/ubuntu/.local/bin:\$PATH\"
                            fi
                            /home/ubuntu/.local/bin/ansible --version || exit 1
                            echo 'Ansible verification passed'
                        " || {
                            echo "ERROR: Ansible verification failed"
                            exit 1
                        }
                        echo ""
                        
                        # Step 3: Configure AWS credentials on bastion and run playbook
                        echo "=== Step 3: Running Ansible Playbook from bastion ==="
                        echo "This will install SonarQube on private instances"
                        echo "Pipeline will wait until installation completes..."
                        echo ""
                        
                        # Verify AWS credentials are available in Jenkins context
                        echo "Verifying AWS credentials in Jenkins context..."
                        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                            echo "ERROR: AWS credentials not available in Jenkins context!"
                            echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-NOT SET}"
                            echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-NOT SET}"
                            exit 1
                        fi
                        echo "AWS credentials available in Jenkins (will be passed to bastion)"
                        echo ""
                        
                        # Run ansible-playbook from bastion with AWS credentials
                        # Pass AWS credentials as environment variables directly in SSH command
                        # This is more secure and reliable than using .bashrc
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST \
                            "AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID' AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY' AWS_DEFAULT_REGION=us-east-1 bash" << 'EOF'
                            set -e
                            # Unset WORKSPACE to ensure Ansible uses bastion's SSH key path, not Jenkins workspace
                            unset WORKSPACE
                            
                            # Force HOME and USER to be ubuntu (prevent jenkins user issues)
                            export HOME=/home/ubuntu
                            export USER=ubuntu
                            
                            # Create ansible-jenkins workspace directory for all Jenkins-related files
                            # Use hardcoded path directly to avoid variable expansion issues in heredoc
                            BASTION_WORKSPACE="/home/ubuntu/ansible-jenkins"
                            echo "Creating Jenkins workspace directory: /home/ubuntu/ansible-jenkins"
                            mkdir -p /home/ubuntu/ansible-jenkins || {
                                echo "ERROR: Failed to create workspace directory: /home/ubuntu/ansible-jenkins"
                                exit 1
                            }
                            echo "Workspace directory created: /home/ubuntu/ansible-jenkins"
                            echo ""
                            
                            # Change to ubuntu's home directory
                            cd /home/ubuntu/ansible-playbook
                            
                            # Use explicit full path (no variable expansion issues)
                            ANSIBLE_BIN_DIR="/home/ubuntu/.local/bin"
                            
                            # Verify variable is set
                            echo "ANSIBLE_BIN_DIR is set to: \${ANSIBLE_BIN_DIR}"
                            
                            # Set PATH to include ansible binaries (use explicit path)
                            export PATH="/home/ubuntu/.local/bin:\$PATH"
                            
                            # Verify environment
                            echo "Current PATH: \$PATH"
                            echo "Current HOME: \$HOME"
                            echo "Current USER: \$(whoami)"
                            echo "Current directory: \$(pwd)"
                            echo "Checking for ansible..."
                            
                            # Debug: Show what we're looking for (use explicit path)
                            echo "Looking for Ansible in: /home/ubuntu/.local/bin"
                            echo "Checking if directory exists..."
                            
                            # Verify we're running as ubuntu user (SSH should make us ubuntu)
                            ACTUAL_USER=\$(whoami)
                            echo "Actual user running this script: \${ACTUAL_USER}"
                            
                            if [ ! -d "/home/ubuntu/.local/bin" ]; then
                                echo "Directory /home/ubuntu/.local/bin does not exist, attempting to create it..."
                                if [ "\${ACTUAL_USER}" = "ubuntu" ]; then
                                    # We're ubuntu, can create directory directly
                                    mkdir -p /home/ubuntu/.local/bin || {
                                        echo "ERROR: Failed to create directory as ubuntu user"
                                        exit 1
                                    }
                                else
                                    # Not ubuntu, try with sudo (requires passwordless sudo)
                                    sudo mkdir -p /home/ubuntu/.local/bin || {
                                        echo "ERROR: Failed to create directory. Running as \${ACTUAL_USER}, need ubuntu user or sudo access"
                                        echo "Directory should already exist if Ansible was installed. Checking if Ansible binaries exist elsewhere..."
                                        find /home/ubuntu -name ansible -type f 2>/dev/null | head -5
                                        exit 1
                                    }
                                    # Fix ownership if created with sudo
                                    sudo chown -R ubuntu:ubuntu /home/ubuntu/.local 2>/dev/null || true
                                fi
                            else
                                echo "Directory /home/ubuntu/.local/bin exists"
                            fi
                            
                            # First, ensure pip is installed
                            echo "Checking if pip is installed..."
                            if ! python3 -m pip --version >/dev/null 2>&1; then
                                echo "pip is not installed. Installing pip and required tools..."
                                sudo apt-get update -qq
                                sudo apt-get install -y python3-pip python3-venv git curl wget awscli
                                # Upgrade pip after installation
                                python3 -m pip install --user --upgrade pip
                                # Set PATH to include user bin directory (where pip installs binaries)
                                export PATH="/home/ubuntu/.local/bin:\$PATH"
                            else
                                echo "pip is already installed"
                                python3 -m pip --version
                                # Ensure PATH includes user bin directory
                                export PATH="/home/ubuntu/.local/bin:\$PATH"
                            fi
                            
                            # Check if ansible binaries exist (use explicit paths)
                            echo "Checking for ansible binaries..."
                            if [ ! -f "/home/ubuntu/.local/bin/ansible" ] || [ ! -f "/home/ubuntu/.local/bin/ansible-inventory" ] || [ ! -f "/home/ubuntu/.local/bin/ansible-playbook" ]; then
                                echo "Ansible binaries not found, checking pip installation..."
                                python3 -m pip list | grep ansible || echo "Ansible not installed via pip"
                                
                                echo "Installing/reinstalling Ansible..."
                                python3 -m pip install --user --force-reinstall ansible boto3 botocore
                                
                                # Verify installation
                                echo "Verifying installation..."
                                python3 -m pip show ansible || echo "Ansible package not found"
                                
                                # Check if binaries were created
                                echo "Checking for binaries after installation..."
                                ls -la "/home/ubuntu/.local/bin/" | grep ansible || {
                                    echo "ERROR: Ansible binaries still not found after installation"
                                    echo "Checking pip user site..."
                                    python3 -m site --user-base
                                    echo "Trying to find ansible..."
                                    find /home/ubuntu -name ansible -type f 2>/dev/null | head -5
                                    exit 1
                                }
                            fi
                            
                            # Set PATH to include ansible binaries
                            export PATH="/home/ubuntu/.local/bin:\$PATH"
                            
                            # Define command paths (use explicit full paths)
                            ANSIBLE_CMD="/home/ubuntu/.local/bin/ansible"
                            ANSIBLE_PLAYBOOK_CMD="/home/ubuntu/.local/bin/ansible-playbook"
                            ANSIBLE_INVENTORY_CMD="/home/ubuntu/.local/bin/ansible-inventory"
                            
                            # Verify all required commands exist (check each one explicitly with full path)
                            echo "Verifying all Ansible binaries exist..."
                            if [ ! -f "/home/ubuntu/.local/bin/ansible-inventory" ]; then
                                echo "ERROR: ansible-inventory not found at: /home/ubuntu/.local/bin/ansible-inventory"
                                echo "Directory contents:"
                                ls -la "/home/ubuntu/.local/bin/" || echo "Cannot list directory"
                                exit 1
                            fi
                            
                            if [ ! -f "/home/ubuntu/.local/bin/ansible-playbook" ]; then
                                echo "ERROR: ansible-playbook not found at: /home/ubuntu/.local/bin/ansible-playbook"
                                exit 1
                            fi
                            
                            if [ ! -f "/home/ubuntu/.local/bin/ansible" ]; then
                                echo "ERROR: ansible not found at: /home/ubuntu/.local/bin/ansible"
                                exit 1
                            fi
                            
                            # Verify all commands are executable (use explicit paths)
                            chmod +x "/home/ubuntu/.local/bin/ansible" "/home/ubuntu/.local/bin/ansible-playbook" "/home/ubuntu/.local/bin/ansible-inventory" 2>/dev/null || true
                            
                            echo "SUCCESS: All Ansible binaries found"
                            echo "Using ansible-inventory from: /home/ubuntu/.local/bin/ansible-inventory"
                            echo "Verifying ansible version..."
                            /home/ubuntu/.local/bin/ansible --version || exit 1
                            
                            # AWS credentials are passed as environment variables in the SSH command
                            # They are already available in this session
                            echo ""
                            echo "Setting AWS credentials and environment variables..."
                            echo "Checking if credentials are available..."
                            
                            # Verify AWS credentials are set (they should be passed from SSH command)
                            if [ -z "\$AWS_ACCESS_KEY_ID" ] || [ -z "\$AWS_SECRET_ACCESS_KEY" ]; then
                                echo "ERROR: AWS credentials not set in SSH session!"
                                echo "AWS_ACCESS_KEY_ID length: \$(echo -n "\$AWS_ACCESS_KEY_ID" | wc -c)"
                                echo "AWS_SECRET_ACCESS_KEY length: \$(echo -n "\$AWS_SECRET_ACCESS_KEY" | wc -c)"
                                echo ""
                                echo "This means credentials were not passed from Jenkins to bastion."
                                echo "Check that withCredentials block is properly configured."
                                exit 1
                            fi
                            
                            # Export additional Ansible environment variables
                            export AWS_DEFAULT_REGION=us-east-1
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            export ANSIBLE_STDOUT_CALLBACK=default
                            export ANSIBLE_FORCE_COLOR=1
                            
                            echo "AWS credentials configured successfully"
                            # Use POSIX-compliant way to show partial credentials
                            AWS_KEY_PREFIX=\$(echo -n "\$AWS_ACCESS_KEY_ID" | cut -c1-10)
                            AWS_SECRET_PREFIX=\$(echo -n "\$AWS_SECRET_ACCESS_KEY" | cut -c1-10)
                            AWS_KEY_LEN=\$(echo -n "\$AWS_ACCESS_KEY_ID" | wc -c)
                            AWS_SECRET_LEN=\$(echo -n "\$AWS_SECRET_ACCESS_KEY" | wc -c)
                            echo "AWS_ACCESS_KEY_ID: \${AWS_KEY_PREFIX}... (length: \${AWS_KEY_LEN})"
                            echo "AWS_SECRET_ACCESS_KEY: \${AWS_SECRET_PREFIX}... (length: \${AWS_SECRET_LEN})"
                            echo ""
                            
                            # Create AWS credentials file for persistence (better than .bashrc)
                            echo "Creating AWS credentials file for persistence..."
                            AWS_CRED_DIR="/home/ubuntu/.aws"
                            mkdir -p "\${AWS_CRED_DIR}" || {
                                echo "WARNING: Failed to create .aws directory, but continuing..."
                            }
                            
                            # Write credentials to AWS credentials file (standard location)
                            if [ -d "\${AWS_CRED_DIR}" ]; then
                                cat > "\${AWS_CRED_DIR}/credentials" << CREDEOF
[default]
aws_access_key_id = \${AWS_ACCESS_KEY_ID}
aws_secret_access_key = \${AWS_SECRET_ACCESS_KEY}
CREDEOF
                                chmod 600 "\${AWS_CRED_DIR}/credentials" || true
                                
                                # Also create config file for region
                                cat > "\${AWS_CRED_DIR}/config" << CONFIGEOF
[default]
region = us-east-1
CONFIGEOF
                                chmod 600 "\${AWS_CRED_DIR}/config" || true
                                
                                echo "SUCCESS: AWS credentials saved to ~/.aws/credentials"
                                echo "Credentials will be available for AWS CLI and SDKs"
                            else
                                echo "WARNING: Could not create .aws directory, credentials only available in this session"
                            fi
                            echo ""
                            
                            echo "=========================================="
                            echo "=== Step 1: Discovering instances using dynamic inventory ==="
                            echo "=========================================="
                            echo "Stage: Dynamic Inventory Discovery"
                            echo "Timestamp: \$(date)"
                            echo ""
                            
                            # Create Ansible control path directory for SSH multiplexing
                            echo "Creating Ansible control path directory..."
                            mkdir -p /home/ubuntu/.ansible/cp || {
                                echo "WARNING: Failed to create .ansible/cp directory, but continuing..."
                            }
                            chmod 700 /home/ubuntu/.ansible 2>/dev/null || true
                            chmod 700 /home/ubuntu/.ansible/cp 2>/dev/null || true
                            echo "Ansible control path directory ready"
                            echo ""
                            
                            # Verify ansible-inventory exists and is executable
                            echo "Verifying ansible-inventory command..."
                            if [ ! -f "/home/ubuntu/.local/bin/ansible-inventory" ]; then
                                echo "ERROR: ansible-inventory not found at /home/ubuntu/.local/bin/ansible-inventory"
                                echo "Checking directory contents:"
                                ls -la /home/ubuntu/.local/bin/ | grep ansible || echo "No ansible binaries found"
                                exit 1
                            fi
                            
                            if [ ! -x "/home/ubuntu/.local/bin/ansible-inventory" ]; then
                                echo "WARNING: ansible-inventory is not executable, fixing permissions..."
                                chmod +x /home/ubuntu/.local/bin/ansible-inventory
                            fi
                            
                            echo "ansible-inventory found and executable"
                            
                            # Verify we're in the correct directory (use $(pwd) without escape so it runs on bastion)
                            CURRENT_DIR=\$(pwd)
                            echo "Current directory: \${CURRENT_DIR}"
                            
                            # Force change to the correct directory
                            echo "Changing to /home/ubuntu/ansible-playbook..."
                            cd /home/ubuntu/ansible-playbook || {
                                echo "ERROR: Failed to change to /home/ubuntu/ansible-playbook"
                                echo "Directory does not exist or permission denied"
                                exit 1
                            }
                            
                            # Verify we're now in the correct directory
                            CURRENT_DIR=\$(pwd)
                            echo "Now in directory: \${CURRENT_DIR}"
                            
                            # Verify aws_ec2.yml exists
                            if [ ! -f "aws_ec2.yml" ]; then
                                echo "ERROR: aws_ec2.yml not found in current directory: \${CURRENT_DIR}"
                                echo "Directory contents:"
                                ls -la
                                exit 1
                            fi
                            echo "SUCCESS: aws_ec2.yml found in: \${CURRENT_DIR}"
                            
                            # Test the command first
                            echo "Testing ansible-inventory command..."
                            /home/ubuntu/.local/bin/ansible-inventory --version || {
                                echo "ERROR: ansible-inventory command failed"
                                exit 1
                            }
                            
                            echo "Running: /home/ubuntu/.local/bin/ansible-inventory -i aws_ec2.yml --list"
                            echo ""
                            
                            # Save inventory output to JSON file in ansible-jenkins workspace
                            INVENTORY_JSON="/home/ubuntu/ansible-jenkins/dynamic_inventory.json"
                            
                            # Run the command with explicit full path (no variables to avoid expansion issues)
                            echo "Executing command: /home/ubuntu/.local/bin/ansible-inventory -i aws_ec2.yml --list"
                            echo "Working directory: \$(pwd)"
                            echo "AWS credentials check:"
                            # Use POSIX-compliant way to show partial credentials
                            AWS_KEY_PREFIX=\$(echo "\$AWS_ACCESS_KEY_ID" | cut -c1-10 2>/dev/null || echo "N/A")
                            AWS_SECRET_PREFIX=\$(echo "\$AWS_SECRET_ACCESS_KEY" | cut -c1-10 2>/dev/null || echo "N/A")
                            echo "  AWS_ACCESS_KEY_ID: \${AWS_KEY_PREFIX}..." 
                            echo "  AWS_SECRET_ACCESS_KEY: \${AWS_SECRET_PREFIX}..."
                            echo "  AWS_DEFAULT_REGION: \${AWS_DEFAULT_REGION}"
                            echo "Inventory will be saved to: \${INVENTORY_JSON}"
                            echo ""
                            
                            # Run command and capture both stdout and stderr
                            echo "Running ansible-inventory command..."
                            echo "Inventory will be saved to: \${INVENTORY_JSON}"
                            if /home/ubuntu/.local/bin/ansible-inventory -i aws_ec2.yml --list > "\${INVENTORY_JSON}" 2>&1; then
                                echo "SUCCESS: Instances discovered"
                                echo ""
                                # Display the inventory
                                cat "\${INVENTORY_JSON}"
                                echo ""
                                echo "Inventory saved to: \${INVENTORY_JSON}"
                            else
                                INVENTORY_EXIT_CODE=\$?
                                echo ""
                                echo "=========================================="
                                echo "ERROR: Step 1 FAILED - Dynamic Inventory Discovery"
                                echo "=========================================="
                                echo "Exit code: \${INVENTORY_EXIT_CODE}"
                                echo "Timestamp: \$(date)"
                                echo ""
                                echo "Possible causes:"
                                echo "  - AWS credentials not set or invalid"
                                echo "  - AWS collection not installed (run: ansible-galaxy collection install amazon.aws)"
                                echo "  - No instances found with tag:env=sonarqube"
                                echo "  - Network connectivity issues"
                                echo ""
                                echo "Check AWS credentials and instance tags"
                                exit 1
                            fi
                            echo ""
                                
                            echo "=========================================="
                            echo "=== Step 2: Testing connectivity to private instances ==="
                            echo "=========================================="
                            echo "Stage: Connectivity Test"
                            echo "Timestamp: \$(date)"
                            echo "Running: ansible ping test"
                            echo ""
                            if /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v; then
                                echo ""
                                echo "SUCCESS: Connectivity test passed - all instances are reachable"
                                echo ""
                            else
                                CONNECTIVITY_EXIT_CODE=\$?
                                echo ""
                                echo "=========================================="
                                echo "ERROR: Step 2 FAILED - Connectivity Test"
                                echo "=========================================="
                                echo "Exit code: \${CONNECTIVITY_EXIT_CODE}"
                                echo "Timestamp: \$(date)"
                                echo ""
                                echo "Possible causes:"
                                echo "  - SSH key not found at ~/.ssh/sonarqube-key.pem on bastion"
                                echo "  - Security groups blocking SSH from bastion to private instances"
                                echo "  - Private instances not running"
                                echo "  - Network ACLs blocking traffic"
                                echo ""
                                echo "Check:"
                                echo "  1. SSH key exists: ls -la ~/.ssh/sonarqube-key.pem"
                                echo "  2. Security group allows SSH from bastion subnet"
                                echo "  3. Instances are in 'running' state"
                                exit 1
                            fi
                            echo ""
                            
                            echo "=========================================="
                            echo "=== Step 3: Running Ansible Playbook ==="
                            echo "=========================================="
                            echo "Installing SonarQube on all discovered instances..."
                            echo "This will show detailed output for each task..."
                            echo ""
                            echo "Starting playbook execution at: \$(date)"
                            echo ""
                            
                            # Save playbook output to file for debugging in ansible-jenkins workspace
                            PLAYBOOK_LOG="/home/ubuntu/ansible-jenkins/ansible-playbook.log"
                            echo "Playbook output will be saved to: \${PLAYBOOK_LOG}"
                            echo ""
                            
                            # Run playbook with verbose output and show task names
                            # Save output to both console and file
                            if /home/ubuntu/.local/bin/ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=~/.ssh/sonarqube-key.pem \
                                --verbose \
                                --diff \
                                site.yml 2>&1 | tee "\${PLAYBOOK_LOG}"; then
                                PLAYBOOK_EXIT_CODE=0
                                echo ""
                                echo "=========================================="
                                echo "SUCCESS: Playbook execution completed successfully"
                                echo "=========================================="
                            else
                                PLAYBOOK_EXIT_CODE=\$?
                                echo ""
                                echo "=========================================="
                                echo "ERROR: Playbook execution FAILED"
                                echo "=========================================="
                                echo "Exit code: \${PLAYBOOK_EXIT_CODE}"
                                echo "Timestamp: \$(date)"
                                echo ""
                                echo "Last 50 lines of playbook output:"
                                echo "----------------------------------------"
                                tail -50 "\${PLAYBOOK_LOG}" || echo "Could not read log file"
                                echo "----------------------------------------"
                                echo ""
                                echo "Full playbook log saved at: \${PLAYBOOK_LOG}"
                                echo "To debug, check the log file or Jenkins console output above"
                                echo ""
                                exit 1
                            fi
                            
                            echo ""
                            echo "Playbook execution completed at: \$(date)"
                            echo "Playbook log saved to: \${PLAYBOOK_LOG}"
                            echo ""
                            
                            echo "=========================================="
                            echo "=== Step 4: Verifying installation ==="
                            echo "=========================================="
                            echo "Checking SonarQube service status on all instances..."
                            echo ""
                            /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m shell \
                                -a "systemctl status sonarqube --no-pager" \
                                -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v || {
                                echo "WARNING: Service status check failed, but this may be expected"
                            }
                            echo ""
                            
                            echo "=========================================="
                            echo "=== Step 5: Final verification ==="
                            echo "=========================================="
                            echo "Checking if SonarQube is running..."
                            /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m shell \
                                -a "systemctl is-active sonarqube && echo 'SonarQube is ACTIVE' || echo 'SonarQube is INACTIVE'" \
                                -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v
                            echo ""
                            
                            echo "=========================================="
                            echo "=== Installation Summary ==="
                            echo "=========================================="
                            echo "Checking installed components on all instances..."
                            echo ""
                            echo "--- Java Version ---"
                            /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m shell \
                                -a "java -version 2>&1 | head -3" \
                                -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v
                            echo ""
                            echo "--- PostgreSQL Status ---"
                            /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m shell \
                                -a "systemctl is-active postgresql && echo 'PostgreSQL is ACTIVE' || echo 'PostgreSQL status unknown'" \
                                -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v
                            echo ""
                            echo "--- SonarQube Service Status ---"
                            /home/ubuntu/.local/bin/ansible -i aws_ec2.yml _sonarqube -m shell \
                                -a "systemctl status sonarqube --no-pager -l | head -10" \
                                -u ubuntu --private-key=~/.ssh/sonarqube-key.pem -v
                            echo ""
                            
                            echo "=========================================="
                            echo "SUCCESS: SonarQube installation completed from bastion host"
                            echo "All tasks executed successfully!"
                            echo "=========================================="
EOF
                        
                        # Copy dynamic inventory JSON file from bastion to Jenkins workspace
                        echo ""
                        echo "=== Copying files from bastion to Jenkins workspace ==="
                        
                        # Copy all files from ansible-jenkins workspace
                        echo "Copying all files from ansible-jenkins workspace..."
                        
                        # Copy inventory JSON
                        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                            ubuntu@$BASTION_HOST:/home/ubuntu/ansible-jenkins/dynamic_inventory.json \
                            "${WORKSPACE}/dynamic_inventory.json" || {
                            echo "WARNING: Failed to copy inventory JSON file, but continuing..."
                        }
                        
                        # Copy playbook log (for debugging if playbook failed)
                        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                            ubuntu@$BASTION_HOST:/home/ubuntu/ansible-jenkins/ansible-playbook.log \
                            "${WORKSPACE}/ansible-playbook.log" 2>/dev/null || {
                            echo "INFO: Playbook log not found (playbook may not have run)"
                        }
                        
                        # List all files in ansible-jenkins workspace for reference
                        echo "Files in ansible-jenkins workspace on bastion:"
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST \
                            "ls -lah /home/ubuntu/ansible-jenkins/ 2>/dev/null || echo 'Directory does not exist'" || true
                        echo ""
                        
                        if [ -f "${WORKSPACE}/dynamic_inventory.json" ]; then
                            echo "SUCCESS: Dynamic inventory saved to: ${WORKSPACE}/dynamic_inventory.json"
                            echo "File size: $(wc -l < ${WORKSPACE}/dynamic_inventory.json) lines"
                        else
                            echo "WARNING: Inventory JSON file not found in workspace"
                        fi
                        
                        if [ -f "${WORKSPACE}/ansible-playbook.log" ]; then
                            echo "SUCCESS: Playbook log saved to: ${WORKSPACE}/ansible-playbook.log"
                            echo "File size: $(wc -l < ${WORKSPACE}/ansible-playbook.log) lines"
                            echo "Use this log to debug any playbook failures"
                        fi
                        
                        echo ""
                        echo "=========================================="
                        echo "=== File Locations Summary ==="
                        echo "=========================================="
                        echo "On Bastion Host:"
                        echo "  Workspace: /home/ubuntu/ansible-jenkins/"
                        echo "  - dynamic_inventory.json"
                        echo "  - ansible-playbook.log"
                        echo ""
                        echo "In Jenkins Workspace:"
                        echo "  - ${WORKSPACE}/dynamic_inventory.json"
                        echo "  - ${WORKSPACE}/ansible-playbook.log"
                        echo ""
                        echo "To access files on bastion:"
                        echo "  ssh -i sonarqube-key.pem ubuntu@<BASTION_IP>"
                        echo "  cd /home/ubuntu/ansible-jenkins"
                        echo "  ls -lah"
                        echo "=========================================="
                        echo ""
                        
                        echo ""
                        echo "=========================================="
                        echo "SUCCESS: Installation completed!"
                        echo "Pipeline waited for Ansible to finish"
                        echo "Dynamic inventory JSON saved to workspace"
                        echo "=========================================="
                    '''
                }
            }
        }
        

    } // end stages

    post {
        
        success {
            echo "=========================================="
            echo "Pipeline completed successfully!"
            echo "Primary task completed: SonarQube installed using dynamic inventory"
            echo "=========================================="
        }
        failure {
            echo "Pipeline failed. Check console output for errors."
        }
    }

} // end pipeline
