pipeline {
    agent any
    environment {
        AWS_CREDS = credentials('aws-credentials')
        // Terraform variables (adjust as per your setup)
        TF_VAR_region = 'us-east-1'
        //TF_VAR_bucket_name = 'sonarqube-terraform-state-123'
        //TF_VAR_dynamodb_table = 'terraform-locks-123'
        SSH_KEY_PATH = "${WORKSPACE}/.ssh/sonarqube-key.pem"
    }
    stages {
        stage('Git Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: '*/main']],
                          doGenerateSubmoduleConfigurations: false,
                          extensions: [],
                          userRemoteConfigs: [[url: 'https://github.com/mukeshdevelp/infra-sonarqube-modular.git', credentialsId: 'github-pat-token']]])
            }
        }
        stage('AWS CLI Test & Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh '''
                        aws s3 ls
                        terraform init
                        echo "terraform initialized"
                    '''
                }
            }
        }
        stage('Terraform Formatting') {
            steps { sh 'terraform fmt && echo "formatted terraform code"' }
        }
        stage('Terraform Validate') {
            steps { sh 'terraform validate && echo "validated terraform code"' }
        }
        stage('Terraform Plan') {
            steps { sh 'terraform plan && echo "planning terraform code"' }
        }
        stage('terraform refresh'){
            steps{
                sh 'terraform refresh'
            }
        }
        stage('Terraform apply') {
            steps { sh 'terraform destroy --auto-approve && echo "creating infra"' }
        }
        stage('storing the private ips') {
            steps {
             sh "./store_ip.sh"
         }
    }   
        // copy the ssh key to ec2 server
        stage('copy ssh key to ec2 server') {
            steps {
                sh 'scp -o StrictHostKeyChecking=no -i ./.ssh/sonarqube-key.pem ./.ssh/sonarqube-key.pem ubuntu@:public-ip/home/ubuntu/'

                
            }
        }

        stage('Test Dynamic Inventory') {
            steps {
                sh '''
                echo "Testing dynamic inventory..."
                ansible-inventory -i aws_ec2.yml --list
                '''
            }
        }
        stage('Git Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: '*/postgres']],
                          doGenerateSubmoduleConfigurations: false,
                          extensions: [],
                          userRemoteConfigs: [[url: 'https://github.com/mukeshdevelp/ansible-assignment-5-v2.git', credentialsId: 'github-pat-token']]])
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                sh '''
                ansible-playbook -i aws_ec2.yml ansible/playbook.yml
                '''
            }
        }
    }
    post {
        success { echo "Stage 1 & 2 completed successfully: repo checked out and infra provisioned." }
        failure { echo "Pipeline failed. Check console output for errors." }
    }
}