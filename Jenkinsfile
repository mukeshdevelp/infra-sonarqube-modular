pipeline {
    agent any

    environment {
        AWS_CREDS = credentials('aws-credentials')
        TF_VAR_region = 'us-east-1'
        TF_VAR_bucket_name = 'sonarqube-terraform-state-12'
        SSH_KEY_PATH = "${WORKSPACE}/.ssh/sonarqube-key.pem"
        // virtual env path
        VENV_PATH = "${WORKSPACE}/venv"
    }

    stages {

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

        stage('AWS CLI Test & Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
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

        stage('Terraform Formatting') {
            steps {
                sh '''
                    export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                    terraform fmt && echo "formatted terraform code"
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                sh '''
                    export TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
                    terraform validate && echo "validated terraform code"
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
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

        stage('Terraform Apply') {
            steps {
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

        stage('Store Private IPs') {
            steps {
                sh '''
                ./store_ip.sh
                
                '''
            }
        }

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
                    
                    # scp to bastion host
                    echo "Copying SSH key to bastion host at ${BASTION_HOST}"
                    scp -i $SSH_KEY_PATH -o StrictHostKeyChecking=no $SSH_KEY_PATH ubuntu@${BASTION_HOST}:/home/ubuntu/.ssh/sonarqube-key.pem
                    
                    # Fix permissions on bastion host
                    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ubuntu@${BASTION_HOST} "chmod 400 /home/ubuntu/.ssh/sonarqube-key.pem"
                    
                    echo "SUCCESS: SSH key copied to bastion host"
                '''
            }
        }

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


        stage('pinging the instances') {
            steps {
                withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh '''
                            #!/bin/bash
                            set -e  # Exit immediately if a command exits with a non-zero status
                            
                            . $VENV_PATH/bin/activate
                            
                            # Explicitly export AWS credentials for Ansible dynamic inventory plugin
                            export AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            
                            # Get bastion host information for ProxyCommand
                            if [ -f "${WORKSPACE}/ips.env" ]; then
                                . "${WORKSPACE}/ips.env"
                            fi
                            
                            # Prefer DNS over IP (DNS is more stable if IP changes)
                            if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                                export BASTION_HOST="$BASTION_PUBLIC_DNS"
                                echo "Using Bastion DNS for ProxyCommand: ${BASTION_HOST}"
                            elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                                export BASTION_HOST="$BASTION_PUBLIC_IP"
                                echo "Using Bastion IP for ProxyCommand: ${BASTION_HOST}"
                            else
                                # Fallback: Get bastion IP/DNS directly from Terraform output
                                BASTION_PUBLIC_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
                                BASTION_PUBLIC_DNS=$(terraform output -raw bastion_public_dns 2>/dev/null || echo "")
                                if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                                    export BASTION_HOST="$BASTION_PUBLIC_DNS"
                                elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                                    export BASTION_HOST="$BASTION_PUBLIC_IP"
                                else
                                    echo "WARNING: Bastion host not found - private instances may not be accessible"
                                fi
                            fi
                            
                            # SSH key path - use SSH_KEY_PATH from environment block
                            SSH_KEY="$SSH_KEY_PATH"
                            echo "WORKSPACE: ${WORKSPACE}"
                            echo "SSH_KEY_PATH: ${SSH_KEY_PATH}"
                            echo "SSH_KEY: $SSH_KEY"
                            echo "BASTION_HOST: ${BASTION_HOST:-not set}"
                            
                            # Fix directory and key permissions
                            SSH_DIR="$(dirname "$SSH_KEY")"
                            if [ ! -d "$SSH_DIR" ]; then
                                echo "ERROR: .ssh directory not found at $SSH_DIR"
                                exit 1
                            fi
                            
                            # Fix .ssh directory permissions (must be 700)
                            chmod 700 "$SSH_DIR"
                            
                            # Check if key exists
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                echo "Listing .ssh directory contents:"
                                ls -la "$SSH_DIR" || echo "Cannot list $SSH_DIR"
                                exit 1
                            fi
                            
                            # Fix key file permissions (must be 400)
                            chmod 400 "$SSH_KEY"
                            echo "SSH key permissions fixed: $(ls -l "$SSH_KEY" | awk '{print $1}')"
                            
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            # Display inventory
                            echo "=== Discovered Instances ==="
                            ansible-inventory -i aws_ec2.yml --graph
                            ansible-inventory -i aws_ec2.yml --list
                            
                            # Ping hosts using ansible - this MUST succeed or pipeline fails
                            echo ""
                            echo "=== Testing SSH Connectivity ==="
                            echo "If ping fails, pipeline will stop immediately"
                            if ! ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key="$SSH_KEY" --timeout=60; then
                                echo "ERROR: SSH connectivity test FAILED"
                                echo "Pipeline will stop here. Infrastructure may be destroyed or instances not ready."
                                exit 1
                            fi
                            echo "SSH connectivity test PASSED - proceeding to next stage"
                        '''
                    }
                }
            }
        }
        
        
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
                        
                        # Get bastion host information
                        if [ -f "${WORKSPACE}/ips.env" ]; then
                            . "${WORKSPACE}/ips.env"
                        fi
                        
                        # Prefer DNS over IP (DNS is more stable if IP changes)
                        if [ -n "$BASTION_PUBLIC_DNS" ] && [ "$BASTION_PUBLIC_DNS" != "N/A" ]; then
                            BASTION_HOST="$BASTION_PUBLIC_DNS"
                        elif [ -n "$BASTION_PUBLIC_IP" ] && [ "$BASTION_PUBLIC_IP" != "N/A" ]; then
                            BASTION_HOST="$BASTION_PUBLIC_IP"
                        else
                            # Fallback: Get bastion IP/DNS directly from Terraform output
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
                        
                        SSH_KEY="${WORKSPACE}/.ssh/sonarqube-key.pem"
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
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST "mkdir -p ~/ansible-playbook"
                        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
                            site.yml \
                            aws_ec2.yml \
                            ansible.cfg \
                            roles/ \
                            ubuntu@$BASTION_HOST:~/ansible-playbook/
                        echo "Files copied successfully"
                        echo ""
                        
                        # Step 2: Install Ansible and dependencies on bastion
                        echo "=== Step 2: Setting up Ansible on bastion ==="
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST << 'BASTION_SETUP'
                            set -e
                            cd ~/ansible-playbook
                            
                            # Check if Ansible is already installed
                            if ! command -v ansible-playbook &> /dev/null; then
                                echo "Installing Ansible and dependencies..."
                                sudo apt-get update -qq
                                sudo apt-get install -y python3-pip python3-venv
                                python3 -m pip install --user --upgrade pip
                                python3 -m pip install --user ansible boto3 botocore
                                
                                # Add pip user bin to PATH for this session
                                export PATH="$HOME/.local/bin:$PATH"
                            else
                                echo "Ansible already installed"
                                export PATH="$HOME/.local/bin:$PATH"
                            fi
                            
                            # Verify Ansible installation
                            ansible --version || python3 -m pip install --user ansible boto3 botocore
                            export PATH="$HOME/.local/bin:$PATH"
                            ansible --version
BASTION_SETUP
                        echo "Ansible setup completed"
                        echo ""
                        
                        # Step 3: Configure AWS credentials on bastion and run playbook
                        echo "=== Step 3: Running Ansible Playbook from bastion ==="
                        echo "This will install SonarQube on private instances"
                        echo "Pipeline will wait until installation completes..."
                        echo ""
                        
                        # Run ansible-playbook from bastion with AWS credentials
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST bash << EOF
                            set -e
                            cd ~/ansible-playbook
                            export PATH="\$HOME/.local/bin:\$PATH"
                            export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
                            export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
                            export AWS_DEFAULT_REGION=us-east-1
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            echo "=== Discovering instances using dynamic inventory ==="
                            ansible-inventory -i aws_ec2.yml --list || {
                                echo "ERROR: Failed to discover instances"
                                exit 1
                            }
                            echo ""
                            
                            echo "=== Testing connectivity to private instances ==="
                            ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=~/.ssh/sonarqube-key.pem || {
                                echo "ERROR: Cannot reach private instances from bastion"
                                exit 1
                            }
                            echo "Connectivity test passed"
                            echo ""
                            
                            echo "=== Running Ansible Playbook ==="
                            echo "Installing SonarQube on all discovered instances..."
                            ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=~/.ssh/sonarqube-key.pem site.yml
                            
                            echo ""
                            echo "=== Verifying installation ==="
                            ansible -i aws_ec2.yml _sonarqube -m shell -a "systemctl status sonarqube --no-pager" -u ubuntu --private-key=~/.ssh/sonarqube-key.pem || echo "Service check completed"
                            
                            echo ""
                            echo "SUCCESS: SonarQube installation completed from bastion host"
EOF
                        
                        echo ""
                        echo "=========================================="
                        echo "SUCCESS: Installation completed!"
                        echo "Pipeline waited for Ansible to finish"
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
