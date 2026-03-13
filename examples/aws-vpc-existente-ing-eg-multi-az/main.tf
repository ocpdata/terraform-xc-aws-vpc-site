provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Crea la Global Virtual Network en F5 XC para conectividad multi-cloud
resource "volterra_virtual_network" "global" {
  name      = "aws-existing-vpc-global-vn"
  namespace = "system"

  global_network = true
}

# Security Group para la interfaz outside (SLO) del nodo XC
resource "aws_security_group" "outside" {
  name        = "f5xc-outside-sg"
  description = "F5 XC outside (SLO) interface security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "IPSec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "XC control plane"
    from_port   = 65500
    to_port     = 65500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VPC local traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "f5xc-outside-sg"
  }
}

# Security Group para la interfaz inside (SLI) del nodo XC
resource "aws_security_group" "inside" {
  name        = "f5xc-inside-sg"
  description = "F5 XC inside (SLI) interface security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "f5xc-inside-sg"
  }
}

module "aws_vpc_site" {
  source = "../.."

  site_name             = "aws-existing-vpc-ing-eg-multi-az"
  aws_region            = "us-east-1"
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Usa una VPC existente en lugar de crear una nueva
  create_aws_vpc            = false
  vpc_id                    = var.vpc_id
  existing_outside_subnets  = var.existing_outside_subnets
  existing_inside_subnets   = var.existing_inside_subnets
  existing_workload_subnets = var.existing_workload_subnets

  # Security groups explícitos para interfaz outside e inside
  custom_security_group = {
    outside_security_group_id = aws_security_group.outside.id
    inside_security_group_id  = aws_security_group.inside.id
  }

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  global_network_connections_list = [{
    sli_to_global_dr = {
      global_vn = {
        name      = volterra_virtual_network.global.name
        namespace = "system"
      }
    }
  }]

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  depends_on = [
    module.aws_cloud_credentials,
    volterra_virtual_network.global,
    aws_security_group.outside,
    aws_security_group.inside,
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  name           = "aws-existing-vpc-creds"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}
