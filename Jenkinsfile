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
                            terraform init --reconfigure
                            echo "terraform initialized"
                        '''
                    }
                }
            }

            stage('Terraform Formatting') {
                steps {
                    sh 'terraform fmt && echo "form atted terraform code"'
                }
            }

            stage('Terraform Validate') {
                steps {
                    sh 'terraform validate && echo "validated terraform code"'
                }
            }

            stage('Terraform Plan') {
                steps {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh 'terraform plan && echo "planning terraform code"'
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
                            # Create .ssh directory if it doesn't exist (required for Terraform key creation)
                            mkdir -p $WORKSPACE/.ssh
                            chmod 700 $WORKSPACE/.ssh
                            
                            terraform apply --auto-approve
                            chmod 400 $WORKSPACE/.ssh/sonarqube-key.pem
                            echo "infra created"
                            echo "ALB DNS: $(terraform output -raw alb_dns_name)"
                            echo "Image Builder IP: $(terraform output -raw image_builder_public_ip 2>/dev/null || terraform output -raw public_ip_of_bastion)"
                            echo "Private Instance IPs:"
                            terraform output -json aws_private_instance_ip | jq -r '.[]'
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
                        
                        
                        # Create virtual environment
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
                                
                                echo "=== Using Dynamic Inventory (aws_ec2.yml) ==="
                                echo "=== Installing SonarQube on Image Builder EC2 ==="
                                
                                # Get Jenkins server's public IP for diagnostics
                                JENKINS_PUBLIC_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "unknown")
                                echo "=== Jenkins Server Public IP: $JENKINS_PUBLIC_IP ==="
                                echo "⚠️  If SSH fails, ensure this IP is in whitelisted_ip in terraform.tfvars"
                                
                                # Set environment variables for dynamic inventory
                                export ANSIBLE_INVENTORY=aws_ec2.yml
                                export ANSIBLE_HOST_KEY_CHECKING=False
                                export ANSIBLE_SSH_TIMEOUT=120
                                
                                # Get Image Builder EC2 IP from Terraform output (simpler and more reliable)
                                echo "=== Getting Image Builder EC2 IP from Terraform ==="
                                IMAGE_BUILDER_IP=$(terraform output -raw image_builder_public_ip 2>/dev/null || echo "")
                                
                                if [ -z "$IMAGE_BUILDER_IP" ]; then
                                    echo "❌ ERROR: Could not get Image Builder EC2 IP from Terraform"
                                    echo "Make sure terraform apply completed successfully"
                                    exit 1
                                fi
                                
                                echo "✅ Image Builder EC2 IP: $IMAGE_BUILDER_IP"
                                
                                # Wait for Image Builder EC2 to appear in dynamic inventory (for Ansible)
                                echo "=== Waiting for Image Builder EC2 to appear in dynamic inventory ==="
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
                                
                                # Display discovered instances
                                echo "=== Discovered instances ==="
                                ansible-inventory -i aws_ec2.yml --list | grep -A 5 "_image_builder" || echo "No _image_builder group found yet"
                                
                                # Wait for SSH to be ready with better diagnostics
                                echo "=== Waiting for Image Builder EC2 ($IMAGE_BUILDER_IP) to be SSH-ready ==="
                                MAX_WAIT=600  # Increased to 10 minutes
                                WAIT_INTERVAL=15
                                ELAPSED=0
                                
                                while [ $ELAPSED -lt $MAX_WAIT ]; do
                                    # First, test direct SSH connection (faster and more reliable)
                                    if timeout 10 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o BatchMode=yes -i ${WORKSPACE}/.ssh/sonarqube-key.pem ubuntu@$IMAGE_BUILDER_IP "echo 'SSH_OK'" 2>&1 | grep -q "SSH_OK"; then
                                        echo "✅ Direct SSH connection successful!"
                                        # Verify with Ansible ping
                                        PING_OUTPUT=$(timeout 15 ansible -i aws_ec2.yml _image_builder -m ping -u ubuntu --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem --timeout=10 2>&1) || true
                                        if echo "$PING_OUTPUT" | grep -qE "SUCCESS|pong"; then
                                            echo "✅ Ansible ping confirmed!"
                                            break
                                        fi
                                    fi
                                    
                                    # Diagnostic output every 60 seconds
                                    if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
                                        echo "=== Diagnostics at ${ELAPSED}s ==="
                                        echo "Testing SSH to $IMAGE_BUILDER_IP..."
                                        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes -i ${WORKSPACE}/.ssh/sonarqube-key.pem ubuntu@$IMAGE_BUILDER_IP "echo test" 2>&1 | head -3 || echo "SSH connection failed"
                                        echo "Checking if instance is running..."
                                        aws ec2 describe-instances --filters "Name=tag:type,Values=image-builder" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' --output table 2>/dev/null || echo "Could not check instance state"
                                    fi
                                    
                                    echo "Waiting for SSH... (${ELAPSED}s/${MAX_WAIT}s)"
                                    sleep $WAIT_INTERVAL
                                    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
                                done
                                
                                # Final check before proceeding
                                if [ $ELAPSED -ge $MAX_WAIT ]; then
                                    echo "❌ ERROR: SSH connection timeout after ${MAX_WAIT}s"
                                    echo "=== Troubleshooting Information ==="
                                    echo "Image Builder IP: $IMAGE_BUILDER_IP"
                                    echo "SSH Key: ${WORKSPACE}/.ssh/sonarqube-key.pem"
                                    echo "Checking instance state..."
                                    aws ec2 describe-instances --filters "Name=tag:type,Values=image-builder" --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name,SecurityGroups[0].GroupId]' --output table
                                    echo "Checking security group rules..."
                                    SG_ID=$(aws ec2 describe-instances --filters "Name=tag:type,Values=image-builder" --query 'Reservations[*].Instances[*].SecurityGroups[0].GroupId' --output text | head -1)
                                    if [ -n "$SG_ID" ]; then
                                        echo "Security Group: $SG_ID"
                                        echo "Current SSH rules:"
                                        aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' --output table
                                        echo ""
                                        echo "Whitelisted IPs in terraform.tfvars:"
                                        echo "  - 103.87.45.36/32"
                                        echo "  - 173.0.0.0/16"
                                        echo ""
                                        echo "Jenkins Server Public IP: $JENKINS_PUBLIC_IP"
                                        echo ""
                                        if [ "$JENKINS_PUBLIC_IP" != "unknown" ]; then
                                            if echo "103.87.45.36 173.0.0.0" | grep -q "$JENKINS_PUBLIC_IP"; then
                                                echo "✅ Jenkins IP appears to be whitelisted"
                                            else
                                                echo "❌ Jenkins IP ($JENKINS_PUBLIC_IP) may not be whitelisted!"
                                                echo "   Add it to whitelisted_ip in terraform.tfvars and run terraform apply"
                                            fi
                                        fi
                                    fi
                                    echo ""
                                    echo "Testing direct SSH connection..."
                                    ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i ${WORKSPACE}/.ssh/sonarqube-key.pem ubuntu@$IMAGE_BUILDER_IP "echo test" 2>&1 | tail -10
                                    exit 1
                                fi
                                
                                # Run playbook on Image Builder EC2 using dynamic inventory
                                echo "=== Running Ansible Playbook on Image Builder EC2 (Dynamic Inventory) ==="
                                echo "This will install SonarQube on the public EC2 (15-30 minutes)..."
                                
                                # Use site.yml but limit to _image_builder group
                                ansible-playbook -i aws_ec2.yml site.yml \
                                    --limit _image_builder \
                                    --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem \
                                    -u ubuntu \
                                    --forks=1 \
                                    -v
                                
                                echo "✅ SonarQube installed on Image Builder EC2!"
                                echo "=== Verifying SonarQube installation ==="
                                ansible -i aws_ec2.yml _image_builder -m shell -a "curl -s http://localhost:9000 | head -20 || echo 'SonarQube starting...'" -u ubuntu --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem || echo "SonarQube may still be starting"
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
                            echo "=== Creating AMI from Image Builder EC2 ==="
                            echo "This will create an AMI with SonarQube pre-installed"
                            
                            # Apply Terraform to create AMI and launch private instances
                            # Step 1: Create AMI from Image Builder EC2 (with SonarQube installed)
                            echo "Step 1: Creating AMI from Image Builder EC2 (with SonarQube)..."
                            terraform apply -auto-approve \
                                -var="create_ami=true" \
                                -target=module.compute.aws_ami_from_instance.sonarqube_ami \
                                -target=module.compute.aws_launch_template.sonarqube_lt \
                                -target=module.compute.null_resource.stop_image_builder
                            
                            # Wait for AMI to be available
                            echo "Waiting for AMI to be available (this may take 2-5 minutes)..."
                            AMI_ID=$(terraform output -raw sonarqube_ami_id 2>/dev/null || echo "")
                            if [ -n "$AMI_ID" ]; then
                                echo "AMI ID: $AMI_ID"
                                echo "Waiting for AMI to be in 'available' state..."
                                aws ec2 wait image-available --image-ids $AMI_ID || echo "AMI may still be creating"
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
                            echo "=== Private Instance IPs (from Launch Template) ==="
                            terraform output -json aws_private_instance_ip | jq -r '.[]'
                            echo ""
                            echo "=== AMI ID ==="
                            terraform output -raw sonarqube_ami_id
                            echo ""
                            echo "=== Launch Template ID ==="
                            terraform output -raw launch_template_id
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
                            script: 'terraform output -raw alb_dns_name 2>/dev/null || echo "N/A"',
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
                echo "✓ Ansible playbook executed"
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
