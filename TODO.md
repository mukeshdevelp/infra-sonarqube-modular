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

