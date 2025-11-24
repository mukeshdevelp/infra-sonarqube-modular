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


        stage('pinging the instances') {
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
                            
                            # SSH key path - use SSH_KEY_PATH from environment block
                            SSH_KEY="$SSH_KEY_PATH"
                            echo "WORKSPACE: ${WORKSPACE}"
                            echo "SSH_KEY_PATH: ${SSH_KEY_PATH}"
                            echo "SSH_KEY: $SSH_KEY"
                            
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
                            
                            # Ping hosts using ansible
                            echo ""
                            echo "=== Testing SSH Connectivity ==="
                            ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key="$SSH_KEY" 
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
