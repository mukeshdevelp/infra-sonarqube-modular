# creating key and saving it to local
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = var.key_name
  public_key = tls_private_key.key.public_key_openssh
}

# Create .ssh directory if it doesn't exist
resource "null_resource" "ssh_directory" {
  triggers = {
    key_location = var.key_location
  }
  
  provisioner "local-exec" {
    command = "mkdir -p $(dirname '${var.key_location}') && chmod 755 $(dirname '${var.key_location}')"
  }
}

resource "local_file" "private_key" {
  depends_on = [null_resource.ssh_directory]
  
  content         = tls_private_key.key.private_key_pem
  filename        = var.key_location
  file_permission = "0400"
  
  lifecycle {
    ignore_changes = [content]
  }
}
