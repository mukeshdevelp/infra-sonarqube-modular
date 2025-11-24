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

        
        stage('Verify SSH Connectivity') {
            steps {
                withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh '''
                            . $VENV_PATH/bin/activate
                            
                            # Explicitly export AWS credentials for Ansible dynamic inventory plugin
                            export AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            
                            # Verify AWS credentials are set
                            if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                                echo "ERROR: AWS credentials not set!"
                                exit 1
                            fi
                            
                            # SSH key is in workspace
                            SSH_KEY="${WORKSPACE}/.ssh/sonarqube-key.pem"
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                echo "Expected location: ${WORKSPACE}/.ssh/sonarqube-key.pem"
                                exit 1
                            fi
                            
                            chmod 400 "$SSH_KEY"
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            # Display inventory
                            echo "=== Discovered Instances ==="
                            ansible-inventory -i aws_ec2.yml --list
                            
                            # Check if instances are in inventory
                            if ! ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "_sonarqube"; then
                                echo ""
                                echo "ERROR: No instances found in inventory with tag:env=sonarqube"
                                echo "Pipeline will fail - instances must be available in inventory"
                                echo ""
                                echo "Possible causes:"
                                echo "  1. Instances not created yet (check Terraform apply stage)"
                                echo "  2. Instances not in 'running' state"
                                echo "  3. Instances don't have tag:env=sonarqube"
                                echo "  4. AWS credentials not working for dynamic inventory"
                                echo "  5. Region mismatch (inventory expects us-east-1)"
                                exit 1
                            fi
                            
                            # Test SSH connectivity - FAIL IMMEDIATELY if unavailable (NO RETRIES)
                            echo "=== Testing SSH Connectivity ==="
                            echo "If SSH connectivity fails, pipeline will fail immediately"
                            if ! ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key="$SSH_KEY" --timeout=30; then
                                echo "ERROR: SSH connectivity failed. Pipeline will fail."
                                echo "Check:"
                                echo "  1. Security groups allow SSH from Jenkins server"
                                echo "  2. Instances are running and have public/private IPs"
                                echo "  3. SSH key is correct"
                                echo "  4. Network connectivity (bastion host if using private IPs)"
                                exit 1
                            fi
                            
                            echo "SUCCESS: SSH connectivity verified"
                        '''
                    }
                }
            }
        }
        
        stage('Install SonarQube using Dynamic Inventory') {
            steps {
                withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh '''
                            . $VENV_PATH/bin/activate
                            
                            # Explicitly export AWS credentials for Ansible dynamic inventory plugin
                            export AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            
                            # Verify AWS credentials are set
                            if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                                echo "ERROR: AWS credentials not set!"
                                exit 1
                            fi
                            
                            # SSH key is in workspace
                            SSH_KEY="${WORKSPACE}/.ssh/sonarqube-key.pem"
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                exit 1
                            fi
                            
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            echo "=========================================="
                            echo "PRIMARY TASK: Installing SonarQube using Dynamic Inventory"
                            echo "=========================================="
                            echo "Using dynamic inventory: aws_ec2.yml"
                            echo "Target hosts: _sonarqube (discovered via AWS EC2 tags)"
                            echo "Playbook: site.yml"
                            echo ""
                            
                            # Display dynamic inventory before running
                            echo "=== Dynamic Inventory Discovery ==="
                            ansible-inventory -i aws_ec2.yml --list
                            echo ""
                            
                            echo "=== Running Ansible Playbook with Dynamic Inventory ==="
                            ansible-playbook -i aws_ec2.yml -u ubuntu --private-key="$SSH_KEY" site.yml
                            
                            echo ""
                            echo "SUCCESS: SonarQube installation completed using dynamic inventory"
                        '''
                    }
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
