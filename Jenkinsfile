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
                sh 'terraform fmt && echo "formatted terraform code"'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate && echo "validated terraform code"'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan && echo "planning terraform code"'
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
                            
                            # SSH key is in workspace
                            SSH_KEY="${WORKSPACE}/.ssh/sonarqube-key.pem"
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                echo "Expected location: ${WORKSPACE}/.ssh/sonarqube-key.pem"
                                exit 1
                            fi
                            
                            chmod 400 "$SSH_KEY"
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            # Wait for instances to appear in inventory (max 2 minutes)
                            echo "Waiting for instances to appear in dynamic inventory..."
                            MAX_WAIT=120
                            ELAPSED=0
                            while [ $ELAPSED -lt $MAX_WAIT ]; do
                                if ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "_sonarqube"; then
                                    echo "Instances found in inventory"
                                    break
                                fi
                                echo "Waiting for instances... (${ELAPSED}s/${MAX_WAIT}s)"
                                sleep 10
                                ELAPSED=$((ELAPSED + 10))
                            done
                            
                            # Display inventory
                            echo "=== Discovered Instances ==="
                            ansible-inventory -i aws_ec2.yml --list
                            
                            # Test SSH connectivity ONCE - fail immediately if it doesn't work
                            echo "=== Testing SSH Connectivity ==="
                            if ! ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key="$SSH_KEY" --timeout=30; then
                                echo "ERROR: SSH connectivity failed. Cannot connect to instances."
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
        
        stage('Run Ansible') {
            steps {
                withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh '''
                            . $VENV_PATH/bin/activate
                            
                            # SSH key is in workspace
                            SSH_KEY="${WORKSPACE}/.ssh/sonarqube-key.pem"
                            
                            if [ ! -f "$SSH_KEY" ]; then
                                echo "ERROR: SSH key not found at $SSH_KEY"
                                exit 1
                            fi
                            
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            echo "=== Running Ansible Playbook ==="
                            ansible-playbook -i aws_ec2.yml -u ubuntu --private-key="$SSH_KEY" site.yml
                        '''
                    }
                }
            }
        }
        

    } // end stages

    post {
        
        success {
            echo "Pipeline completed successfully: Infra created + Ansible executed."
        }
        failure {
            echo "Pipeline failed. Check console output for errors."
        }
    }

} // end pipeline
