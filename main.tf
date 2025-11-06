
# Root Module (main.tf)

# vpc module resources
module "vpc" {
  source         = "./modules/vpc"
  cidr_block     = var.cidr_block
  vpc_name       = var.vpc_name
  public_subnets = module.subnets.public_subnets

}

# subnet module resources
module "subnets" {
  source = "./modules/subnet"

  vpc_id                = module.vpc.vpc_id
  availability_zones    = var.availability_zones
  public_subnets_cidrs  = var.public_subnets_cidrs
  private_subnets_cidrs = var.private_subnets_cidrs
}




# security group resources
module "security_groups" {
  source     = "./modules/security_groups"
  vpc_id     = module.vpc.vpc_id
  allowed_ip = var.whitelisted_ip
  subnet_id  = concat(module.subnets.public_subnets, module.subnets.private_subnets)

  app_port   = var.app_port

}
# nacl module resources
module "nacl" {
  source = "./modules/nacls"
  vpc_id = module.vpc.vpc_id
  # might be mistake here
  public_subnets     = module.subnets.public_subnets        
  private_subnets    = module.subnets.private_subnets
  private_cidr_block = "10.0.0.0/16" 
}
# dikkat yha hai
# route module resources
module "routes" {
  source          = "./modules/routes"
  public_subnets  = module.subnets.public_subnets
  private_subnets = module.subnets.private_subnets

  vpc_id         = module.vpc.vpc_id
  igw_id         = module.vpc.igw_id
  nat_gateway_id = module.vpc.nat_gateway_id
}
# compute resources
module "sonarqube_compute" {
  source                = "./modules/compute"
  key_name              = var.key_name
  private_key_file_path = var.private_key_file_path
  ami_name              = var.ami_name
  launch_template_name  = var.launch_template_name
  instance_type         = var.instance_type
  security_group_ids    = [module.security_groups.private_sg_id.id]
  instance_name         = var.instance_name
}
# finished---------------
# alb module resources
module "sonarqube_alb" {
  source          = "./modules/alb" # Path to the ALB module
  lb_name         = var.alb_name
  internal        = false
  security_groups = [ module.security_groups.private_sg_id.id]
  subnets = module.subnets.private_subnets
  vpc_id            = module.vpc.vpc_id
  target_group_name = var.target_group_name
  health_check_path = "/"
  health_check_port = 9000
  target_group_port = 9000
  listener_port     = 80
}


# finished----------6nov



module "sonarqube_asg" {
  source             = "./modules/asg"
  asg_name           = var.asg_name
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  private_subnets    = module.subnets.private_subnets
  target_group_arn   = module.sonarqube_alb.target_group_arn
  launch_template_id = module.sonarqube_compute.launch_template_id
  lb_listener_arn    = module.sonarqube_alb.alb_arn
}



