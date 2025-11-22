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
                sh '''
                    terraform apply --auto-approve
                    chmod 400 $WORKSPACE/.ssh/sonarqube-key.pem

                    echo "infra created"
                '''
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

        
        stage('Run Ansible') {
            steps {
                withEnv(["PATH=${env.WORKSPACE}/venv/bin:${env.PATH}"]) {
                sh """
                     ansible-inventory -i aws_ec2.yml --list
                     export ANSIBLE_HOST_KEY_CHECKING=False
                     until ansible -i aws_ec2.yml all -m ping -u ubuntu --private-key=.ssh/sonarqube-key.pem; do
                      echo "Waiting for hosts to be ready..."
                      sleep 15
                    done
                    ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=${env.WORKSPACE}/.ssh/sonarqube-key.pem site.yml
    
                     
                """
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
