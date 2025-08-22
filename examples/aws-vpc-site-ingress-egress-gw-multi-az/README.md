# Ingress/Egress Gateway AWS VPC Site with 3 AZs for F5 XC Cloud

The following example will create an Ingress/Egress Gateway AWS VPC Site in F5 XC Cloud with 3 availability zones and security groups. This configuration provides high availability and advanced networking capabilities including global network connectivity.

## Usage

```hcl
module "aws_vpc_site_ingress_egress_gw" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-ingress-egress-gw-multi-az"
  aws_region            = "us-west-2"
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_cidr              = "172.10.0.0/16"
  
  # Subnet configuration for each AZ
  outside_subnets  = ["172.10.11.0/24", "172.10.12.0/24", "172.10.13.0/24"]
  workload_subnets = ["172.10.21.0/24", "172.10.22.0/24", "172.10.23.0/24"]
  inside_subnets   = ["172.10.31.0/24", "172.10.32.0/24", "172.10.33.0/24"]

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
    AZs         = "multi-az"
  }

  depends_on = [
    module.aws_cloud_credentials
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  name           = "aws-example-creds"
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
- **Subnets**: 9 subnets across 3 AZs (3 types × 3 AZs):
  - Outside subnets: For internet-facing traffic
  - Inside subnets: For internal network communication
  - Workload subnets: For application workloads
- **Security Groups**: Managed security groups for network access
- **F5 XC Site**: Multi-AZ ingress/egress gateway configuration
- **Global Connectivity**: Optional connection to F5 XC global networks

## Variables

Key variables for this configuration:

| Variable                          | Description                                   | Default  |
| --------------------------------- | --------------------------------------------- | -------- |
| `site_name`                       | Name for the AWS VPC Site                     | Required |
| `aws_region`                      | AWS region for deployment                     | Required |
| `master_nodes_az_names`           | List of 3 availability zones                  | Required |
| `outside_subnets`                 | CIDR blocks for outside subnets (3 required)  | Required |
| `inside_subnets`                  | CIDR blocks for inside subnets (3 required)   | Required |
| `workload_subnets`                | CIDR blocks for workload subnets (3 required) | Required |
| `global_network_connections_list` | Global network configurations                 | `[]`     |

## Requirements

| Name                                                                                                                 | Version    |
| -------------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="requirement_terraform"></a> [terraform](https://www.terraform.io/)                                          | >= 1.0     |
| <a name="requirement_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 4.65.0  |
| <a name="requirement_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.26 |

## Providers

| Name                                                                                                              | Version    |
| ----------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="provider_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.26 |
| <a name="provider_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 4.65.0  |