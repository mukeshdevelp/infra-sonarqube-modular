root/
├─ main.tf           # Calls the modules and passes variables
├─ variables.tf      
├─ outputs.tf        
├─ modules/
│  ├─ vpc/                  # VPC creation
│  │  ├─ main.tf       
│  │  ├─ variables.tf  
│  │  └─ outputs.tf    
│  ├─ compute/              # EC2 launch templates, key pairs
│  │  ├─ main.tf      
│  │  ├─ variables.tf  
│  │  └─ outputs.tf    
│  ├─ alb/                  # Application Load Balancer
│  │  ├─ main.tf     
│  │  ├─ variables.tf  
│  │  └─ outputs.tf   
│  ├─ asg/                  # Auto Scaling Group
│  │  ├─ main.tf     
│  │  ├─ variables.tf  
│  │  └─ outputs.tf   
│  ├─ subnets/              # Public & private subnets
│  │  ├─ main.tf       
│  │  ├─ variables.tf  
│  │  └─ outputs.tf    
│  ├─ nacl/                 # Network ACLs
│  │  ├─ main.tf       
│  │  ├─ variables.tf  
│  │  └─ outputs.tf    
│  ├─ security_groups/       # All security groups
│  │  ├─ main.tf       
│  │  ├─ variables.tf  
│  │  └─ outputs.tf  
│  └─ routes/               # Route tables and associations
│     ├─ main.tf       
│     ├─ variables.tf  
│     └─ outputs.tf  

 
 Error: Unsupported attribute
│ 
│   on main.tf line 96, in module "sonarqube_asg":
│   96:   launch_template_id = module.sonarqube_compute.launch_template_id.id
│     ├────────────────
│     │ module.sonarqube_compute.launch_template_id is a string
│ 
│ Can't access attributes on a primitive-typed value (string).
╵
╷
│ Error: Invalid value for input variable
│ 
│   on variables.tf line 149:
│  149: variable "min_size" {
│ 
│ Unsuitable value for var.min_size set using an interactive prompt: a number is required.
╵
Releasing state lock. This may take a few moments...
Releasing state lock. This may take a few moments...

resource "aws_instance" "sonarqube_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.sonarqube_key.key_name
  vpc_security_group_ids = var.security_group_ids

  user_data = aws_launch_template.sonarqube_lt.user_data

  tags = {
    Name = var.instance_name
  }
}
