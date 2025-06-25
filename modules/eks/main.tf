module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size

      tags = merge(var.tags, {
        Name = "${var.cluster_name}-node-group"
      })
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}
