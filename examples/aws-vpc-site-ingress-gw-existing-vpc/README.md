# Ingress Gateway AWS VPC Site with Existing VPC for F5 XC Cloud

The following example demonstrates how to create an Ingress Gateway AWS VPC Site in F5 XC Cloud using an existing AWS VPC infrastructure. This example uses the F5 XC AWS VPC Site Networking module to create the networking components separately, then references them in the site configuration.

## Usage

```hcl
# Create or reference existing VPC networking components
module "aws_vpc" {
  source  = "f5devcentral/aws-vpc-site-networking/xc"
  version = "0.0.6"

  name          = "aws-example-ingress-gw-vpc"
  vpc_cidr      = "172.10.0.0/16"
  az_names      = ["us-west-2a"]
  local_subnets = ["172.10.1.0/24"]
}

# Create the F5 XC AWS VPC Site using existing VPC
module "aws_vpc_site_ingress_gw_existing_vpc" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name              = "aws-example-ingress-gw-existing"
  aws_region             = "us-west-2"
  site_type              = "ingress_gw"
  master_nodes_az_names  = ["us-west-2a"]
  create_aws_vpc         = false
  vpc_id                 = module.aws_vpc.vpc_id
  existing_local_subnets = module.aws_vpc.local_subnet_ids

  custom_security_group = {
    outside_security_group_id = module.aws_vpc.outside_security_group_id
  }

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  tags = {
    Environment = "example"
    Purpose     = "ingress-gateway"
    VPC         = "existing"
  }

  depends_on = [
    module.aws_cloud_credentials
  ]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  name           = "aws-example-creds-existing-vpc"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  tags = {
    Environment = "example"
  }
}
```

## Architecture

This example creates:

- **Existing VPC**: Uses AWS VPC Site Networking module to create/manage VPC infrastructure
- **Local Subnets**: Dedicated subnets for F5 XC site deployment
- **Security Groups**: Custom security groups for ingress traffic control
- **F5 XC Site**: Ingress gateway configuration using existing VPC resources
- **Route Tables**: Local route tables for proper traffic routing

## Use Cases

This configuration is ideal when you need to:

- **Integrate with existing infrastructure**: Deploy F5 XC sites into pre-existing AWS environments
- **Separate networking concerns**: Use dedicated networking modules for infrastructure management
- **Maintain compliance**: Work within existing VPC and security group policies
- **Phased deployments**: Add F5 XC capabilities to existing AWS workloads

## Variables

Key variables for this configuration:

| Variable                     | Description                                     | Default  |
| ---------------------------- | ----------------------------------------------- | -------- |
| `site_name`                  | Name for the AWS VPC Site                       | Required |
| `aws_region`                 | AWS region for deployment                       | Required |
| `site_type`                  | Site type (set to "ingress_gw")                 | Required |
| `master_nodes_az_names`      | List with single availability zone              | Required |
| `create_aws_vpc`             | Create new VPC (set to false for existing VPC)  | `false`  |
| `vpc_id`                     | ID of existing VPC                              | Required |
| `existing_local_subnets`     | List of existing subnet IDs for site deployment | Required |
| `custom_security_group`      | Custom security group configuration             | Required |
| `aws_cloud_credentials_name` | Name of AWS credentials in F5 XC                | Required |

## Outputs

| Name                        | Description                                |
| --------------------------- | ------------------------------------------ |
| `site_name`                 | Name of the configured AWS VPC Site        |
| `site_id`                   | ID of the configured AWS VPC Site          |
| `master_public_ip_address`  | Public IP address of the master node       |
| `vpc_id`                    | The ID of the VPC (from networking module) |
| `local_subnet_ids`          | The IDs of the local subnets               |
| `outside_security_group_id` | The ID of the outside security group       |
| `local_route_table_ids`     | The IDs of the local route tables          |

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

## Modules

| Name                                                                                                                                             | Version |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| <a name="module_aws_vpc"></a> [aws-vpc-site-networking](https://registry.terraform.io/modules/f5devcentral/aws-vpc-site-networking/xc)           | 0.0.6   |
| <a name="module_aws_cloud_credentials"></a> [aws-cloud-credentials](https://registry.terraform.io/modules/f5devcentral/aws-cloud-credentials/xc) | 0.0.4   |