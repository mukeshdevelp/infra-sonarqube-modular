1. Networking (VPC, Subnets, Routes, NAT, IGW)

| AWS Service               | Resource Type          | Terraform Name     | AWS Console Name / Tag |
| ------------------------- | ---------------------- | ------------------ | ---------------------- |
| **VPC**                   | `aws_vpc`              | `sonarqube_vpc`    | `sonarqube-vpc`        |
| **Internet Gateway**      | `aws_internet_gateway` | `igw`              | `sonarqube-igw`        |
| **Elastic IP**            | `aws_eip`              | `nat_eip`          | `nat-eip`              |
| **NAT Gateway**           | `aws_nat_gateway`      | `nat_gw`           | `sonarqube-nat`        |
| **Route Table (Public)**  | `aws_route_table`      | `public_rt`        | `public-route-table`   |
| **Route Table (Private)** | `aws_route_table`      | `private_rt`       | `private-route-table`  |
| **Public Subnet A**       | `aws_subnet`           | `public_subnet_a`  | `public-subnet-a`      |
| **Public Subnet B**       | `aws_subnet`           | `public_subnet_b`  | `public-subnet-b`      |
| **Private Subnet A**      | `aws_subnet`           | `private_subnet_a` | `private-subnet-a`     |
| **Private Subnet B**      | `aws_subnet`           | `private_subnet_b` | `private-subnet-b`     |
---
2. Security Layer (Security Groups)

| AWS Service                   | Resource Type        | Terraform Name | AWS Console Name / Tag |
| ----------------------------- | -------------------- | -------------- | ---------------------- |
| **Public Security Group**     | `aws_security_group` | `public_sg`    | `public-sg`            |
| **Private Security Group**    | `aws_security_group` | `private_sg`   | `private-sg`           |
| **PostgreSQL Security Group** | `aws_security_group` | `postgres_sg`  | `postgres-sg`          |
---
3. Load Balancer Layer

| AWS Service                   | Resource Type         | Terraform Name  | AWS Console Name / Tag                  |
| ----------------------------- | --------------------- | --------------- | --------------------------------------- |
| **Application Load Balancer** | `aws_lb`              | `sonarqube_alb` | `sonarqube-alb`                         |
| **Target Group**              | `aws_lb_target_group` | `sonarqube_tg`  | `sonarqube-tg`                          |
| **Listener (HTTP)**           | `aws_lb_listener`     | `alb_listener`  | n/a (appears under ALB > Listeners tab) |
---
4. Compute Layer (Launch Template + Auto Scaling Group + EC2)

| AWS Service                 | Resource Type           | Terraform Name  | AWS Console Name / Tag |
| --------------------------- | ----------------------- | --------------- | ---------------------- |
| **Launch Template**         | `aws_launch_template`   | `sonarqube_lt`  | `sonarqube-lt-`        |
| **Auto Scaling Group**      | `aws_autoscaling_group` | `sonarqube_asg` | `sonarqube-asg`        |
| **EC2 Instances (via ASG)** | created automatically   | —               | `sonarqube-instance`   |
---
5. SSH Key Management

| AWS Service                 | Resource Type     | Terraform Name  | AWS Console Name / Tag                     |
| --------------------------- | ----------------- | --------------- | ------------------------------------------ |
| **TLS Private Key (local)** | `tls_private_key` | `sonarqube_key` | (local file only)                          |
| **AWS Key Pair**            | `aws_key_pair`    | `sonarqube_key` | `sonarqube-key`                            |
| **Local PEM File**          | `local_file`      | `private_key`   | `.ssh/sonarqube-key.pem` (on your machine) |
---
6. State Management (Remote State & Locking)

| AWS Service        | Resource Type        | Example Name                  | Purpose                                           |
| ------------------ | -------------------- | ----------------------------- | ------------------------------------------------- |
| **S3 Bucket**      | `aws_s3_bucket`      | `sonarqube-terraform-state-1` | Stores Terraform state file (`terraform.tfstate`) |
| **DynamoDB Table** | `aws_dynamodb_table` | `terraform-locks`             | Prevents multiple applies at once (state locking) |
