
# Root Module (main.tf)

module "vpc" {
  source                     = "./modules/vpc"
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_a_az         = var.public_subnet_a_az
  public_subnet_a_cidr_block = var.public_subnet_a_cidr_block

  public_subnet_b_az         = var.public_subnet_b_az
  public_subnet_b_cidr_block = var.public_subnet_b_cidr_block



  private_subnet_a_cidr_block = var.private_subnet_a_cidr_block

  private_subnet_a_az = var.private_subnet_a_az

  private_subnet_b_cidr_block = var.private_subnet_b_cidr_block

  private_subnet_b_az = var.private_subnet_b_az
}

module "network" {
  source          = "./modules/network"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets

}

module "security" {
  source                   = "./modules/security"
  vpc_id                   = module.vpc.vpc_id
  allowed_host             = var.whitelisted_ip
  everywhere_host          = var.all_hosts
  pub_subnet_a_association = module.vpc.public_subnets[0]
  pub_subnet_b_association = module.vpc.public_subnets[1]
  pri_subnet_a_association = module.vpc.private_subnets[0]
  pri_subnet_b_association = module.vpc.private_subnets[1]
  vpc_cidr_block           = module.vpc.vpc_cidr_block
  public_subnet_a_cidr     = var.public_subnet_a_cidr_block
  public_subnet_b_cidr     = var.public_subnet_b_cidr_block
  peered_vpc_cidr          = var.peered_vpc_cidr

}

module "keypair" {
  source = "./modules/keypair"
  # pointing the child module variable to root module variable
  key_name     = var.key_pair_name
  key_location = var.ec2_key_location
}

module "compute" {
  source          = "./modules/compute"
  private_subnets = module.vpc.private_subnets

  private_sg = [module.security.private_sg_id]

  target_group_arn = module.alb.target_group_arn

  public_subnet_a_id = module.vpc.public_subnets[0]

  public_security_group = module.security.public_sg_id

  key_name = module.keypair.key_name

  small_instance_size     = var.instance_size_small
  sonarqube_instance_size = var.instance_size_big_for_sonarqube

  # ASG variables (not currently used but kept for future use)
  desired_number = var.desired_number
  max_number     = var.max_number
  min_number     = var.min_number
  alb_listener   = [module.alb.alb_listener]
}

module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  public_sg_id   = module.security.public_sg_id

}


# Get available availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Try to find existing VPC for peering in us-east-1 (optional - will skip if not found)
# Both VPCs must be in us-east-1 for peering to work
data "aws_vpc" "existing_vpc" {
  count = var.existing_vpc_id != "" ? 1 : 0
  id    = var.existing_vpc_id
}

# FETCH ROUTE TABLES OF EXISTING VPC (if it exists)
data "aws_route_tables" "existing_vpc_rts" {
  count  = var.existing_vpc_id != "" ? 1 : 0
  vpc_id = data.aws_vpc.existing_vpc[0].id
}

# VPC Peering - only create if existing VPC ID is provided
# Both VPCs must be in us-east-1
module "vpc_peering" {
  source = "./modules/peering"
  count  = var.existing_vpc_id != "" ? 1 : 0

  # REQUESTER → EXISTING VPC (173.0.0.0/16) in us-east-1
  requester_vpc_id       = data.aws_vpc.existing_vpc[0].id
  requester_vpc_cidr     = var.peered_vpc_cidr
  requester_route_tables = data.aws_route_tables.existing_vpc_rts[0].ids

  # ACCEPTER → NEW VPC (10.0.0.0/16) in us-east-1
  accepter_vpc_id       = module.vpc.vpc_id
  accepter_vpc_cidr     = module.vpc.vpc_cidr_block
  accepter_route_tables = [module.network.private_rt_id]

  # META CONFIG - Both VPCs in same region (us-east-1)
  name        = "peering-173-to-10"
  auto_accept = true
  # peer_region not needed since both VPCs are in us-east-1

  tags = {
    Project = "sonarqube-deployment"
    Owner   = "Mukesh"
    Region  = "us-east-1"
  }
}
