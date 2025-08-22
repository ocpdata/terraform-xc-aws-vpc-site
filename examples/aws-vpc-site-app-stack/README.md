# App Stack AWS VPC Site with single AZ for F5 XC Cloud

The following example will create an App Stack (Voltstack Cluster) AWS VPC Site in F5 XC Cloud with single AZ and a security group. This site type is suitable for running Kubernetes workloads.

```hcl
module "aws_vpc_site_app_stack" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-app-stack"
  aws_region            = "us-west-2"
  site_type             = "app_stack"
  master_nodes_az_names = ["us-west-2a"]
  vpc_cidr              = "172.10.0.0/16"
  local_subnets         = ["172.10.1.0/24"]

  aws_cloud_credentials_name = "your_cloud_credentials_name"
  block_all_services         = false

  # Kubernetes cluster configuration
  k8s_cluster = {
    name = "app-stack-k8s"
  }

  # Use default storage
  default_storage = true

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  depends_on = [ 
    module.aws-cloud-credentials
  ]
}
```

## Variables

Key variables specific to the App Stack site type:

- `k8s_cluster`: Kubernetes cluster configuration object
- `default_storage`: Use default storage class (boolean)
- `dc_cluster_group`: DC cluster group configuration

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
