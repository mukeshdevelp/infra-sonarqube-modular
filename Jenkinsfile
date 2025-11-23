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
                            # Comprehensive cleanup for second run issues
                            echo "=== Comprehensive Cleanup (Preventing Second Run Failures) ==="
                            
                            # 1. Clean SSH control sockets and known hosts
                            echo "Cleaning SSH connections..."
                            rm -rf /tmp/ansible-ssh-* 2>/dev/null || true
                            rm -rf /tmp/ssh-* 2>/dev/null || true
                            rm -rf ~/.ssh/known_hosts 2>/dev/null || true
                            rm -rf ${WORKSPACE}/.ssh/known_hosts 2>/dev/null || true
                            
                            # 2. Clean Ansible cache and temp files
                            echo "Cleaning Ansible cache..."
                            rm -rf ~/.ansible/cp 2>/dev/null || true
                            rm -rf ~/.ansible/tmp 2>/dev/null || true
                            rm -rf ${WORKSPACE}/.ansible 2>/dev/null || true
                            rm -rf /tmp/ansible-* 2>/dev/null || true
                            
                            # 3. Clean AWS EC2 inventory cache
                            echo "Cleaning inventory cache..."
                            rm -rf ~/.cache/ansible 2>/dev/null || true
                            rm -rf ${WORKSPACE}/.cache 2>/dev/null || true
                            
                            # 4. Kill any stale SSH processes (if any)
                            pkill -f "ssh.*10.0." 2>/dev/null || true
                            
                            # Verify SSH key exists
                            if [ ! -f ${WORKSPACE}/.ssh/sonarqube-key.pem ]; then
                                echo "ERROR: SSH key not found at ${WORKSPACE}/.ssh/sonarqube-key.pem"
                                exit 1
                            fi
                            chmod 400 ${WORKSPACE}/.ssh/sonarqube-key.pem
                            
                            # Force refresh dynamic inventory (clear all cache)
                            echo "=== Refreshing Ansible Inventory (Fresh Lookup) ==="
                            export ANSIBLE_INVENTORY_CACHE=False
                            export ANSIBLE_INVENTORY_CACHE_PLUGIN=auto
                            export ANSIBLE_CACHE_PLUGIN=memory
                            export ANSIBLE_GATHERING=explicit
                            # Clear any cached inventory (use --flush-cache instead of --refresh-cache)
                            echo "=== Full Inventory Output ==="
                            ansible-inventory -i aws_ec2.yml --list --flush-cache 2>&1 | tee /tmp/inventory_output.json
                            
                            echo ""
                            echo "=== Checking for _sonarqube group ==="
                            if grep -q "_sonarqube" /tmp/inventory_output.json 2>/dev/null; then
                                echo "✅ _sonarqube group found!"
                                echo "Group members:"
                                ansible-inventory -i aws_ec2.yml _sonarqube --list 2>&1
                            else
                                echo "❌ _sonarqube group NOT found!"
                                echo "Available groups:"
                                ansible-inventory -i aws_ec2.yml --list 2>&1 | grep -E '"(all|ungrouped|aws_ec2|tag_|env_|_)' | head -20
                                echo ""
                                echo "Checking if instances have correct tags..."
                                echo "Instances found:"
                                ansible-inventory -i aws_ec2.yml --list 2>&1 | grep -oP '10\\.0\\.\\d+\\.\\d+' | head -10
                            fi
                            echo ""
                            
                            # Wait for instances to be ready and SSH service to be up
                            echo "=== Waiting for EC2 instances to be ready (SSH service) ==="
                            MAX_WAIT=300  # 5 minutes max wait
                            WAIT_INTERVAL=10
                            ELAPSED=0
                            
                            while [ $ELAPSED -lt $MAX_WAIT ]; do
                                echo "Checking instance readiness (${ELAPSED}s elapsed)..."
                                # Try to get inventory and check if hosts are reachable
                                INVENTORY_OUTPUT=$(ansible-inventory -i aws_ec2.yml --list 2>&1)
                                if echo "$INVENTORY_OUTPUT" | grep -q "_sonarqube"; then
                                    echo "Instances found in inventory, testing SSH connectivity..."
                                    # Try a quick SSH test to one instance
                                    FIRST_HOST=$(ansible-inventory -i aws_ec2.yml _sonarqube --list 2>&1 | grep -oP '10\\.0\\.\\d+\\.\\d+' | head -1)
                                    if [ -n "$FIRST_HOST" ]; then
                                        echo "Testing SSH to $FIRST_HOST..."
                                        if timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${WORKSPACE}/.ssh/sonarqube-key.pem ubuntu@${FIRST_HOST} "echo 'SSH ready'" 2>/dev/null; then
                                            echo "✅ SSH is ready on instances!"
                                            break
                                        fi
                                    fi
                                fi
                                echo "Instances not ready yet, waiting ${WAIT_INTERVAL}s..."
                                sleep $WAIT_INTERVAL
                                ELAPSED=$((ELAPSED + WAIT_INTERVAL))
                            done
                            
                            if [ $ELAPSED -ge $MAX_WAIT ]; then
                                echo "⚠️  WARNING: Instances may not be fully ready, but proceeding anyway..."
                            fi
                            
                            # Test connectivity with fresh connections (no caching)
                            echo "=== Testing Connectivity (Fresh Connections, No Cache) ==="
                            export ANSIBLE_SSH_TIMEOUT=30
                            export ANSIBLE_TIMEOUT=30
                            export ANSIBLE_SSH_RETRIES=3
                            export ANSIBLE_CACHE_PLUGIN=memory
                            export ANSIBLE_GATHERING=explicit
                            export ANSIBLE_FORCE_COLOR=False
                            
                            # Use explicit SSH args to prevent ANY connection reuse
                            # Retry ping up to 5 times with increasing delays
                            PING_RETRIES=5
                            PING_RETRY_DELAY=15
                            PING_SUCCESS=false
                            
                            for i in $(seq 1 $PING_RETRIES); do
                                echo "=== Ping attempt $i of $PING_RETRIES ==="
                                if ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu \
                                    --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem \
                                    -e "ansible_ssh_timeout=30" \
                                    -e "ansible_ssh_common_args='-o ControlMaster=no -o ControlPath=none -o ControlPersist=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o ConnectTimeout=20 -o BatchMode=yes -o TCPKeepAlive=yes'" \
                                    --flush-cache \
                                    -v 2>&1 | tee /tmp/ping_output.log; then
                                    PING_SUCCESS=true
                                    echo "✅ Ping successful!"
                                    break
                                else
                                    echo "❌ Ping failed, waiting ${PING_RETRY_DELAY}s before retry..."
                                    if [ $i -lt $PING_RETRIES ]; then
                                        sleep $PING_RETRY_DELAY
                                        PING_RETRY_DELAY=$((PING_RETRY_DELAY + 5))  # Increase delay each retry
                                    fi
                                fi
                            done
                            
                            if [ "$PING_SUCCESS" = false ]; then
                                echo "❌ ERROR: All ping attempts failed after $PING_RETRIES retries"
                                echo "This might indicate:"
                                echo "  1. VPC peering routes not configured correctly"
                                echo "  2. Security groups blocking SSH from Jenkins VPC"
                                echo "  3. Network ACLs blocking traffic"
                                echo "  4. Instances not fully booted"
                                echo ""
                                echo "Last ping output:"
                                cat /tmp/ping_output.log 2>/dev/null || echo "No output captured"
                                exit 1
                            fi
                            
                            # Run playbook with explicit settings and cache flushing
                            # Increased timeouts and keepalive for long-running playbooks
                            echo "=== Running Ansible Playbook (No Cache, Fresh State) ==="
                            ansible-playbook -i aws_ec2.yml site.yml \
                                --private-key=${WORKSPACE}/.ssh/sonarqube-key.pem \
                                -u ubuntu \
                                -e "ansible_ssh_timeout=60" \
                                -e "ansible_ssh_common_args='-o ControlMaster=no -o ControlPath=none -o ControlPersist=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=12 -o ConnectTimeout=30 -o BatchMode=yes -o TCPKeepAlive=yes -o Compression=no'" \
                                --flush-cache \
                                --forks=1 \
                                -v
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
