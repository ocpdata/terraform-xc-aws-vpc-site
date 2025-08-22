# Ingress/Egress Gateway AWS VPC Site with Single AZ for F5 XC Cloud

The following example will create an Ingress/Egress Gateway AWS VPC Site in F5 XC Cloud with a single availability zone and security groups. This configuration provides a cost-effective deployment option with basic networking capabilities including global network connectivity.


## Usage

```hcl
module "aws_vpc_site_ingress_egress_gw_single_az" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-ingress-egress-gw-single-az"
  aws_region            = "us-west-2"
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["us-west-2a"]
  vpc_cidr              = "172.10.0.0/16"
  
  # Subnet configuration for single AZ
  outside_subnets  = ["172.10.11.0/24"]
  workload_subnets = ["172.10.21.0/24"]
  inside_subnets   = ["172.10.31.0/24"]

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  # Global network connectivity
  global_network_connections_list = [{
    sli_to_global_dr = {
      global_vn = {
        name = "sli-to-global-dr"
      }
    }
  }]

  tags = {
    Environment = "example"
    Purpose     = "ingress-egress-gateway"
    AZs         = "single-az"
  }

  depends_on = [
    module.aws_cloud_credentials
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  name           = "aws-example-creds-single-az"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  tags = {
    Environment = "example"
  }
}
```

## Architecture

This example creates:

- **VPC**: New AWS VPC with specified CIDR block
- **Subnets**: 3 subnets in single AZ:
  - Outside subnet: For internet-facing traffic
  - Inside subnet: For internal network communication
  - Workload subnet: For application workloads
- **Security Groups**: Managed security groups for network access
- **F5 XC Site**: Single-AZ ingress/egress gateway configuration
- **Global Connectivity**: Optional connection to F5 XC global networks

## Variables

Key variables for this configuration:

| Variable                          | Description                                 | Default  |
| --------------------------------- | ------------------------------------------- | -------- |
| `site_name`                       | Name for the AWS VPC Site                   | Required |
| `aws_region`                      | AWS region for deployment                   | Required |
| `master_nodes_az_names`           | List with single availability zone          | Required |
| `outside_subnets`                 | CIDR block for outside subnet (1 required)  | Required |
| `inside_subnets`                  | CIDR block for inside subnet (1 required)   | Required |
| `workload_subnets`                | CIDR block for workload subnet (1 required) | Required |
| `global_network_connections_list` | Global network configurations               | `[]`     |
| `block_all_services`              | Block all services on the site              | `false`  |

## Requirements

| Name                                                                                                                 | Version    |
| -------------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="requirement_terraform"></a> [terraform](https://www.terraform.io/)                                          | >= 1.0     |
| <a name="requirement_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 6.9.0   |
| <a name="requirement_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |

## Providers

| Name                                                                                                              | Version    |
| ----------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="provider_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |
| <a name="provider_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 6.9.0   |