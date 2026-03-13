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
  name      = "aws-global-vn-multi-az"
  namespace = "system"

  global_network = true
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
    volterra_virtual_network.global
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  name           = "aws-tf-test-creds"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}
