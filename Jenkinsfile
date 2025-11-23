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
                            echo "Bastion IP: $(terraform output -raw public_ip_of_bastion)"
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

            stage('Run Ansible') {
                steps {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}", "WORKSPACE=${env.WORKSPACE}", "ANSIBLE_HOST_KEY_CHECKING=False"]) {
                            sh '''
                                # Activate virtual environment
                                . $VENV_PATH/bin/activate
                                
                                # Change to ansible repo directory (after checkout)
                                cd $WORKSPACE
                                
                                # Check if inventory.yml exists (for static inventory)
                                if [ -f inventory.yml ]; then
                                    echo "=== Using static inventory (inventory.yml) ==="
                                    export ANSIBLE_INVENTORY=inventory.yml
                                    
                                    # Test connectivity
                                    echo "=== Testing connectivity to servers ==="
                                    ansible all -m ping || echo "⚠️  Ping failed, but continuing..."
                                    
                                    # Run playbook with static inventory
                                    echo "=== Running Ansible Playbook (Static Inventory) ==="
                                    ansible-playbook -i inventory.yml site.yml
                                else
                                    echo "=== Using dynamic inventory (aws_ec2.yml) ==="
                                    
                                    # Wait for instances to be ready
                                    echo "=== Waiting for EC2 instances to be ready ==="
                                    MAX_RETRIES=30
                                    RETRY_COUNT=0
                                    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                                        if ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "_sonarqube"; then
                                            echo "✅ Instances found in inventory"
                                            break
                                        fi
                                        echo "Waiting for instances... ($RETRY_COUNT/$MAX_RETRIES)"
                                        sleep 10
                                        RETRY_COUNT=$((RETRY_COUNT + 1))
                                    done
                                    
                                    # Test connectivity
                                    echo "=== Testing connectivity ==="
                                    ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem || echo "⚠️  Ping failed, but continuing..."
                                    
                                    # Run playbook with dynamic inventory
                                    echo "=== Running Ansible Playbook (Dynamic Inventory) ==="
                                    ansible-playbook -i aws_ec2.yml site.yml \
                                        --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem \
                                        -u ubuntu
                                fi
                                
                                echo "✅ Playbook execution completed!"
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
