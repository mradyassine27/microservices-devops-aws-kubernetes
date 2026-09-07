module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs            = ["${var.aws_region}a"]
  public_subnets = [var.public_subnet_cidr]

  # Pas de subnet privé ni de NAT Gateway : l'EC2 vit directement
  # en subnet public, ce qui évite le coût du NAT Gateway (~30-40$/mois).
  enable_nat_gateway = false

  map_public_ip_on_launch = true

  tags = {
    Project = var.project_name
  }
}