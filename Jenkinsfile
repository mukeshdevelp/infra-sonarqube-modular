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
                        terraform apply --auto-approve
                        chmod 400 $WORKSPACE/.ssh/sonarqube-key.pem
                        
                        # Copy SSH key to a persistent location before Ansible checkout
                        mkdir -p /tmp/jenkins-ssh-keys
                        cp $WORKSPACE/.ssh/sonarqube-key.pem /tmp/jenkins-ssh-keys/sonarqube-key.pem
                        chmod 400 /tmp/jenkins-ssh-keys/sonarqube-key.pem
                        
                        echo "=== Infrastructure Created Successfully ==="
                        echo "ALB DNS: $(terraform output -raw alb_dns_name)"
                        echo "Bastion IP: $(terraform output -raw public_ip_of_bastion)"
                        echo "Private Instance IPs:"
                        terraform output -json aws_private_instance_ip | jq -r '.[]'
                    '''
                }
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

        stage('Copy SSH Key to Ansible Repo') {
            steps {
                sh '''
                    # Copy SSH key from persistent location to Ansible workspace
                    cp /tmp/jenkins-ssh-keys/sonarqube-key.pem $WORKSPACE/sonarqube-key.pem
                    chmod 400 $WORKSPACE/sonarqube-key.pem
                    echo "SSH key copied to Ansible workspace"
                '''
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

        
        stage('Run Ansible') {
            steps {
                withCredentials([[$class: '                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                        sh """
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            
                            echo "=== Waiting for EC2 instances to be ready ==="
                            MAX_RETRIES=20
                            RETRY_COUNT=0
                            
                            until ansible-inventory -i aws_ec2.yml --list | grep -q "_sonarqube" || [ \$RETRY_COUNT -ge \$MAX_RETRIES ]; do
                                echo "Attempt \$((RETRY_COUNT + 1))/\$MAX_RETRIES: Waiting for instances to appear in inventory..."
                                sleep 30
                                RETRY_COUNT=\$((RETRY_COUNT + 1))
                            done
                            
                            if [ \$RETRY_COUNT -ge \$MAX_RETRIES ]; then
                                echo "ERROR: Instances did not appear in inventory after \$MAX_RETRIES attempts"
                                exit 1
                            fi
                            
                            echo "=== Testing connectivity to instances ==="
                            until ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=sonarqube-key.pem || [ \$RETRY_COUNT -ge \$MAX_RETRIES ]; do
                                echo "Attempt \$((RETRY_COUNT + 1))/\$MAX_RETRIES: Waiting for SSH connectivity..."
                                sleep 30
                                RETRY_COUNT=\$((RETRY_COUNT + 1))
                            done
                            
                            if [ \$RETRY_COUNT -ge \$MAX_RETRIES ]; then
                                echo "ERROR: Could not establish SSH connectivity after \$MAX_RETRIES attempts"
                                exit 1
                            fi
                            
                            echo "=== Running Ansible Playbook ==="
                            ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=sonarqube-key.pem site.yml
                            
                            if [ \$? -eq 0 ]; then
                                echo "=== Ansible Playbook Completed Successfully ==="
                            else
                                echo "ERROR: Ansible Playbook failed"
                                exit 1
                            fi
                        """
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
                        script: 'cd $WORKSPACE && terraform output -raw alb_dns_name 2>/dev/null || echo "N/A"',
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
