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
  name      = "aws-global-vn"
  namespace = "system"

  global_network = true
}

module "aws_vpc_site" {
  source = "../.."

  site_name             = "aws-example-ingress-egress-gw"
  aws_region            = "us-east-1"
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["us-east-1a"]
  vpc_cidr              = var.vpc_cidr
  outside_subnets       = var.outside_subnets
  workload_subnets      = var.workload_subnets
  inside_subnets        = var.inside_subnets

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  # Conecta la subnet inside del site con la Global Virtual Network
  global_network_connections_list = [{
    sli_to_global_dr = {
      global_vn = {
        name = volterra_virtual_network.global.name
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
