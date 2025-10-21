module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  environment          = var.environment
  tags                 = var.tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  environment     = var.environment
  tags            = var.tags

  instance_types        = var.instance_types
  node_group_min_size   = var.node_group_min_size
  node_group_max_size   = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
}