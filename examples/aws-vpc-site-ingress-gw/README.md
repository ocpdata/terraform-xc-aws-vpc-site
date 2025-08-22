# Ingress Gateway AWS VPC Site with Single AZ for F5 XC Cloud

The following example will create an Ingress Gateway AWS VPC Site in F5 XC Cloud with a single availability zone and security groups. This configuration provides inbound traffic processing capabilities for applications and services.

## Usage

```hcl
module "aws_vpc_site_ingress_gw" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-ingress-gw"
  aws_region            = "us-west-2"
  site_type             = "ingress_gw"
  master_nodes_az_names = ["us-west-2a"]
  vpc_cidr              = "172.10.0.0/16"
  local_subnets         = ["172.10.1.0/24"]

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  tags = {
    Environment = "example"
    Purpose     = "ingress-gateway"
    AZs         = "single-az"
  }

  depends_on = [
    module.aws_cloud_credentials
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  name           = "aws-example-creds-ingress"
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
- **Subnets**: Local subnet in single AZ for workload placement
- **Security Groups**: Managed security groups for ingress traffic control
- **F5 XC Site**: Single-AZ ingress gateway configuration
- **Route Tables**: Local route tables for subnet routing

## Variables

Key variables for this configuration:

| Variable                     | Description                              | Default  |
| ---------------------------- | ---------------------------------------- | -------- |
| `site_name`                  | Name for the AWS VPC Site                | Required |
| `aws_region`                 | AWS region for deployment                | Required |
| `site_type`                  | Site type (set to "ingress_gw")          | Required |
| `master_nodes_az_names`      | List with single availability zone       | Required |
| `local_subnets`              | CIDR block for local subnet (1 required) | Required |
| `vpc_cidr`                   | CIDR block for the VPC                   | Required |
| `aws_cloud_credentials_name` | Name of AWS credentials in F5 XC         | Required |
| `block_all_services`         | Block all services on the site           | `false`  |

## Outputs

| Name                        | Description                          |
| --------------------------- | ------------------------------------ |
| `site_name`                 | Name of the configured AWS VPC Site  |
| `site_id`                   | ID of the configured AWS VPC Site    |
| `master_public_ip_address`  | Public IP address of the master node |
| `vpc_id`                    | The ID of the VPC                    |
| `local_subnet_ids`          | The IDs of the local subnets         |
| `outside_security_group_id` | The ID of the outside security group |
| `local_route_table_ids`     | The IDs of the local route tables    |

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