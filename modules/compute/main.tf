# modules/compute/main.tf

resource "tls_private_key" "sonarqube_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sonarqube_key" {
  key_name   = var.key_name
  public_key = tls_private_key.sonarqube_key.public_key_openssh
}

# Optional: Save private key to a local file
resource "local_file" "private_key" {
  content         = tls_private_key.sonarqube_key.private_key_pem
  filename        = var.private_key_file_path
  file_permission = "0600"
}

# Lookup for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Launch Template (SonarQube EC2 Instance)
resource "aws_launch_template" "sonarqube_lt" {
  name                   = var.launch_template_name
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.sonarqube_key.key_name
  vpc_security_group_ids = var.security_group_ids

  # Ensure user data is properly base64 encoded using base64encode()
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1
    echo "Starting user data script"
    sudo apt update -y
    sudo apt install -y docker.io git
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts
    echo "Script completed"

    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.instance_name
    }
  }
}

