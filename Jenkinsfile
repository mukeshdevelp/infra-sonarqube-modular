pipeline {
    agent any

    environment {
        AWS_CREDS = credentials('aws-credentials')
        TF_VAR_region = 'us-east-1'
        TF_VAR_bucket_name = 'sonarqube-terraform-state-12'
        // SSH key path matches terraform.tfvars: ../.ssh/sonarqube-key.pem
        // In Jenkins, this translates to workspace-relative path
        SSH_KEY_PATH = "${WORKSPACE}/../.ssh/sonarqube-key.pem"
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
                        echo "✅ Terraform initialized"
                    '''
                }
            }
        }

        stage('Terraform Formatting') {
            steps {
                sh 'terraform fmt && echo "✅ Terraform code formatted"'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate && echo "✅ Terraform code validated"'
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform plan && echo "✅ Terraform plan completed"'
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
                            chmod 400 $WORKSPACE/../.ssh/sonarqube-key.pem
                        fi
                        
                        echo "✅ Infrastructure created"
                        echo ""
                        echo "=== Infrastructure Outputs ==="
                        echo "ALB DNS: $(terraform output -raw alb_dns_name 2>/dev/null || echo 'N/A')"
                        echo "Image Builder IP: $(terraform output -raw image_builder_public_ip 2>/dev/null || terraform output -raw public_ip_of_bastion 2>/dev/null || echo 'N/A')"
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
                        echo "⚠️  store_ip.sh not found, skipping"
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
                        echo "⚠️  python3-venv not found, attempting to install..."
                        sudo -n apt-get update -qq && sudo -n apt-get install -y python3-venv || echo "⚠️  Could not install python3-venv (may need manual installation)"
                    fi
                    
                    # Create virtual environment
                    python3 -m venv $VENV_PATH
                    . $VENV_PATH/bin/activate
                    echo "✅ Virtual environment activated at $VIRTUAL_ENV"
                    
                    pip install --upgrade pip --quiet
                    pip install boto3 botocore ansible --quiet
                    # Ansible collection
                    ansible-galaxy collection install amazon.aws --quiet
                    echo "✅ Dependencies installed successfully"
                '''
            }
        }

        stage('Install SonarQube on Image Builder EC2') {
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
                            
                            echo "=== Installing SonarQube on Image Builder EC2 ==="
                            echo "Using Dynamic Inventory (aws_ec2.yml)"
                            
                            # Set environment variables for dynamic inventory
                            export ANSIBLE_INVENTORY=aws_ec2.yml
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            export ANSIBLE_SSH_TIMEOUT=120
                            
                            # Get Image Builder EC2 IP from AWS
                            echo "=== Getting Image Builder EC2 IP from AWS ==="
                            MAX_WAIT_FOR_IP=180
                            WAIT_COUNT=0
                            IMAGE_BUILDER_IP=""
                            
                            while [ $WAIT_COUNT -lt 18 ]; do
                                RAW_IP=$(aws ec2 describe-instances --filters "Name=tag:type,Values=image-builder" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
                                
                                if [ -n "$RAW_IP" ] && [ "$RAW_IP" != "None" ] && [ "$RAW_IP" != "null" ]; then
                                    if echo "$RAW_IP" | grep -qE '^[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+$'; then
                                        IMAGE_BUILDER_IP="$RAW_IP"
                                        echo "✅ Image Builder EC2 IP: $IMAGE_BUILDER_IP"
                                        break
                                    fi
                                fi
                                
                                echo "Waiting for Image Builder EC2... ($WAIT_COUNT/18)"
                                sleep 10
                                WAIT_COUNT=$((WAIT_COUNT + 1))
                            done
                            
                            if [ -z "$IMAGE_BUILDER_IP" ] || [ "$IMAGE_BUILDER_IP" = "None" ]; then
                                echo "❌ ERROR: Could not get Image Builder EC2 IP from AWS"
                                aws ec2 describe-instances --filters "Name=tag:type,Values=image-builder" --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' --output table
                                exit 1
                            fi
                            
                            # Wait for Image Builder EC2 to appear in dynamic inventory
                            echo "=== Waiting for Image Builder EC2 in dynamic inventory ==="
                            MAX_RETRIES=30
                            RETRY_COUNT=0
                            
                            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                                if ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "_image_builder"; then
                                    echo "✅ Image Builder EC2 found in dynamic inventory"
                                    break
                                fi
                                echo "Waiting for Image Builder EC2 in inventory... ($RETRY_COUNT/$MAX_RETRIES)"
                                sleep 10
                                RETRY_COUNT=$((RETRY_COUNT + 1))
                            done
                            
                            # Wait for SSH to be ready
                            echo "=== Waiting for Image Builder EC2 ($IMAGE_BUILDER_IP) to be SSH-ready ==="
                            MAX_WAIT=300
                            WAIT_INTERVAL=15
                            ELAPSED=0
                            SSH_SUCCESS=false
                            
                            # SSH key path - try multiple locations
                            SSH_KEY="${WORKSPACE}/../.ssh/sonarqube-key.pem"
                            if [ ! -f "$SSH_KEY" ]; then
                                SSH_KEY="${WORKSPACE}/../infra-sonarqube-modular/.ssh/sonarqube-key.pem"
                            fi
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "❌ ERROR: SSH key not found at $SSH_KEY"
                                echo "Looking for key in:"
                                find ${WORKSPACE}/.. -name "sonarqube-key.pem" 2>/dev/null || echo "Key not found"
                                exit 1
                            fi
                            
                            chmod 400 "$SSH_KEY"
                            echo "✅ Using SSH key: $SSH_KEY"
                            
                            while [ $ELAPSED -lt $MAX_WAIT ]; do
                                if timeout 10 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o BatchMode=yes -i "$SSH_KEY" ubuntu@$IMAGE_BUILDER_IP "echo 'SSH_OK'" 2>&1 | grep -q "SSH_OK"; then
                                    echo "✅ Direct SSH connection successful!"
                                    PING_OUTPUT=$(timeout 15 ansible -i aws_ec2.yml _image_builder -m ping -u ubuntu --private-key="$SSH_KEY" --timeout=10 2>&1) || true
                                    if echo "$PING_OUTPUT" | grep -qE "SUCCESS|pong"; then
                                        echo "✅ Ansible ping confirmed!"
                                        SSH_SUCCESS=true
                                        break
                                    fi
                                fi
                                
                                if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
                                    echo "=== Diagnostics at ${ELAPSED}s ==="
                                    timeout 5 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY" ubuntu@$IMAGE_BUILDER_IP "echo test" 2>&1 | head -3 || echo "SSH connection failed"
                                fi
                                
                                echo "Waiting for SSH... (${ELAPSED}s/${MAX_WAIT}s)"
                                sleep $WAIT_INTERVAL
                                ELAPSED=$((ELAPSED + WAIT_INTERVAL))
                            done
                            
                            if [ "$SSH_SUCCESS" != "true" ]; then
                                echo "❌ ERROR: SSH connection timeout after ${MAX_WAIT}s"
                                echo "Image Builder IP: $IMAGE_BUILDER_IP"
                                echo "SSH Key: $SSH_KEY"
                                exit 1
                            fi
                            
                            # Run playbook on Image Builder EC2
                            echo "=== Running Ansible Playbook on Image Builder EC2 ==="
                            echo "This will install SonarQube (15-30 minutes)..."
                            
                            ansible-playbook -i aws_ec2.yml site.yml \
                                --limit _image_builder \
                                -u ubuntu \
                                --private-key="$SSH_KEY" \
                                --forks=1 \
                                -v
                            
                            echo "✅ SonarQube installed on Image Builder EC2!"
                            echo "=== Verifying SonarQube installation ==="
                            ansible -i aws_ec2.yml _image_builder -m shell -a "curl -s http://localhost:9000 | head -20 || echo 'SonarQube starting...'" -u ubuntu --private-key="$SSH_KEY" || echo "SonarQube may still be starting"
                        '''
                    }
                }
            }
        }
            
        stage('Create AMI and Launch Private Instances') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        cd $TERRAFORM_DIR
                        
                        echo "=== Creating AMI from Image Builder EC2 ==="
                        echo "This will create an AMI with SonarQube pre-installed"
                        
                        # Step 1: Create AMI from Image Builder EC2
                        echo "Step 1: Creating AMI from Image Builder EC2..."
                        terraform apply -auto-approve \
                            -var="create_ami=true" \
                            -target=module.compute.aws_ami_from_instance.sonarqube_ami \
                            -target=module.compute.aws_launch_template.sonarqube_lt \
                            -target=module.compute.null_resource.stop_image_builder
                        
                        # Wait for AMI to be available
                        echo "Waiting for AMI to be available (2-5 minutes)..."
                        AMI_ID=$(terraform output -raw sonarqube_ami_id 2>/dev/null || echo "")
                        if [ -n "$AMI_ID" ] && [ "$AMI_ID" != "AMI not created" ]; then
                            echo "AMI ID: $AMI_ID"
                            aws ec2 wait image-available --image-ids $AMI_ID || echo "⚠️  AMI may still be creating"
                        else
                            echo "⚠️  Could not get AMI ID"
                        fi
                        
                        # Step 2: Launch private instances using the AMI
                        echo "Step 2: Launching private instances from AMI..."
                        terraform apply -auto-approve \
                            -var="create_ami=true" \
                            -var="create_private_instances=true" \
                            -target=module.compute.aws_instance.private_server_a \
                            -target=module.compute.aws_instance.private_server_b \
                            -target=module.compute.aws_lb_target_group_attachment.private_a_attachment \
                            -target=module.compute.aws_lb_target_group_attachment.private_b_attachment
                        
                        echo "✅ AMI created and private instances launched!"
                        echo ""
                        echo "=== Deployment Summary ==="
                        echo "Private Instance IPs:"
                        terraform output -json aws_private_instance_ip 2>/dev/null | jq -r '.[]' || echo "No private instances"
                        echo ""
                        echo "AMI ID:"
                        terraform output -raw sonarqube_ami_id 2>/dev/null || echo "N/A"
                        echo ""
                        echo "Launch Template ID:"
                        terraform output -raw launch_template_id 2>/dev/null || echo "N/A"
                    '''
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
                        echo "✓ SonarQube ALB DNS: http://${albDns}"
                    }
                    echo "=========================================="
                } catch (Exception e) {
                    echo "Could not retrieve ALB DNS: ${e.getMessage()}"
                }
            }
        }
        success {
            echo "=========================================="
            echo "✓ Pipeline completed successfully!"
            echo "✓ Infrastructure created"
            echo "✓ SonarQube installed on Image Builder"
            echo "✓ AMI created"
            echo "✓ Private instances launched"
            echo "=========================================="
        }
        failure {
            echo "=========================================="
            echo "✗ Pipeline failed!"
            echo "Check console output above for errors"
            echo "=========================================="
        }
    }

} // end pipeline
