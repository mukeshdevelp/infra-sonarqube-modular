pipeline {
    agent any

    environment {
        AWS_CREDS = credentials('aws-credentials')
        TF_VAR_region = 'us-east-1'
        TF_VAR_bucket_name = 'sonarqube-terraform-state-12'
        // SSH key path matches terraform.tfvars: ../.ssh/sonarqube-key.pem
        // In Jenkins, this translates to workspace-relative path
        SSH_KEY_PATH = "${WORKSPACE}/.ssh/sonarqube-key.pem"
        // virtual env path
        VENV_PATH = "${WORKSPACE}/venv"
        TERRAFORM_DIR = "${WORKSPACE}"
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
                        terraform init --reconfigure
                        echo "Terraform initialized"
                    '''
                }
            }
        }

        stage('Terraform Formatting') {
            steps {
                sh 'terraform fmt && echo "Terraform code formatted"'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate && echo "Terraform code validated"'
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform plan && echo "Terraform plan completed"'
                }
            }
        }

        stage('Terraform Apply - Create Infrastructure') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        # Create .ssh directory if it doesn't exist (required for Terraform key creation)
                        mkdir -p $WORKSPACE/../.ssh
                        chmod 700 $WORKSPACE/../.ssh
                        
                        # Apply Terraform to create infrastructure (Image Builder EC2)
                        terraform apply -auto-approve
                        
                        # Set key permissions
                        if [ -f $WORKSPACE/../.ssh/sonarqube-key.pem ]; then
                            chmod 400 $WORKSPACE/.ssh/sonarqube-key.pem
                        fi
                        
                        echo "Infrastructure created"
                        echo ""
                        echo "=== Infrastructure Outputs ==="
                        echo "ALB DNS: $(terraform output -raw alb_dns_name 2>/dev/null || echo 'N/A')"
                        echo "Bastion IP: $(terraform output -raw bastion_public_ip 2>/dev/null || echo 'N/A')"
                        echo "Private Instance IPs: $(terraform output -json aws_private_instance_ip 2>/dev/null | jq -r '.[]' || echo 'Not created yet')"
                    '''
                }
            }
        }

        stage('Store Private IPs') {
            steps {
                sh '''
                    if [ -f ./store_ip.sh ]; then
                        ./store_ip.sh
                    else
                        echo "store_ip.sh not found, skipping"
                    fi
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
                    # Check if python3-venv is installed
                    if ! dpkg -l | grep -q python3-venv; then
                        echo "  python3-venv not found, attempting to install..."
                        sudo -n apt-get update -qq && sudo -n apt-get install -y python3-venv || echo "WARNING: Could not install python3-venv (may need manual installation)"
                    fi
                    
                    # Create virtual environment
                    python3 -m venv $VENV_PATH
                    . $VENV_PATH/bin/activate
                    echo "Virtual environment activated at $VIRTUAL_ENV"
                    
                    pip install --upgrade pip --quiet
                    pip install boto3 botocore ansible --quiet
                    # Ansible collection
                    ansible-galaxy collection install amazon.aws
                    echo " Dependencies installed successfully"
                '''
            }
        }

        stage('Install SonarQube on Private Instances') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}", "WORKSPACE=${env.WORKSPACE}", "ANSIBLE_HOST_KEY_CHECKING=False"]) {
                        sh '''
                            . $VENV_PATH/bin/activate
                            cd $WORKSPACE
                            
                            echo "=== Installing SonarQube on Private Instances ==="
                            echo "Using Dynamic Inventory (aws_ec2.yml) with tags: env=sonarqube, role=sonarqube-postgres"
                            
                            # Set environment variables for dynamic inventory
                            export ANSIBLE_INVENTORY=aws_ec2.yml
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            export ANSIBLE_SSH_TIMEOUT=120
                            
                            # Get Bastion IP from Terraform output
                            echo "=== Getting Bastion IP from Terraform ==="
                            cd $TERRAFORM_DIR
                            BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
                            cd $WORKSPACE
                            
                            if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" = "None" ] || [ "$BASTION_IP" = "null" ] || [ "$BASTION_IP" = "" ]; then
                                echo "ERROR: Could not get Bastion IP from Terraform"
                                echo "Make sure Terraform Apply stage completed successfully."
                                cd $TERRAFORM_DIR
                                terraform output 2>/dev/null || echo "No Terraform outputs available"
                                exit 1
                            fi
                            
                            echo "Bastion IP: $BASTION_IP"
                            
                            # Wait for private instances to appear in dynamic inventory
                            echo "=== Waiting for Private Instances in dynamic inventory ==="
                            MAX_RETRIES=30
                            RETRY_COUNT=0
                            
                            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                                if ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "private-server"; then
                                    echo "Private instances found in dynamic inventory"
                                    break
                                fi
                                echo "Waiting for private instances in inventory (tags: env=sonarqube, role=sonarqube-postgres)... ($RETRY_COUNT/$MAX_RETRIES)"
                                sleep 10
                                RETRY_COUNT=$((RETRY_COUNT + 1))
                            done
                            
                            # SSH key path
                            SSH_KEY="${WORKSPACE}/../.ssh/sonarqube-key.pem"
                            if [ ! -f "$SSH_KEY" ]; then
                                SSH_KEY="${WORKSPACE}/../infra-sonarqube-modular/.ssh/sonarqube-key.pem"
                            fi
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                exit 1
                            fi
                            
                            chmod 400 "$SSH_KEY"
                            echo "Using SSH key: $SSH_KEY"
                            
                            # Run playbook on private instances using dynamic inventory
                            echo "=== Running Ansible Playbook on Private Instances ==="
                            echo "This will install SonarQube and PostgreSQL (15-30 minutes)..."
                            
                            ansible-playbook -i aws_ec2.yml site.yml \
                                --limit "tag_role_sonarqube-postgres" \
                                -u ubuntu \
                                --private-key="$SSH_KEY" \
                                --forks=1 \
                                -v
                            
                            echo "SUCCESS: SonarQube installed on Private Instances!"
                        '''
                    }
                }
            }
        }

    } // end stages

    post {
        always {
            script {
                try {
                    def albDns = sh(
                        script: 'cd $TERRAFORM_DIR && terraform output -raw alb_dns_name 2>/dev/null || echo "N/A"',
                        returnStdout: true
                    ).trim()
                    echo "=========================================="
                    echo "Pipeline Execution Summary"
                    echo "=========================================="
                    if (albDns != "N/A" && albDns != "") {
                        echo "SonarQube ALB DNS: http://${albDns}"
                    }
                    echo "=========================================="
                } catch (Exception e) {
                    echo "Could not retrieve ALB DNS: ${e.getMessage()}"
                }
            }
        }
        success {
            echo "=========================================="
            echo "Pipeline completed successfully!"
            echo "Infrastructure created"
            echo "SonarQube installed on Private Instances"
            echo "=========================================="
        }
        failure {
            echo "=========================================="
            echo "Pipeline failed!"
            echo "Check console output above for errors"
            echo "=========================================="
        }
    }

} // end pipeline
