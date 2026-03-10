provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "volterra_k8s_cluster" "this" {
  name      = "app-stack-k8s"
  namespace = "system"

  no_cluster_wide_apps               = true
  use_default_cluster_role_bindings  = true
  use_default_cluster_roles          = true
  cluster_scoped_access_deny         = true
  global_access_enable               = true
  no_insecure_registries             = true
  no_local_access                    = true
  use_default_pod_security_admission = true
  use_default_psp                    = true
  vk8s_namespace_access_deny         = true
}

module "aws_vpc_site" {
  source = "../.."

  site_name             = "aws-example-app-stack"
  aws_region            = "us-east-1"
  site_type             = "app_stack"
  master_nodes_az_names = ["us-east-1a"]
  vpc_cidr              = "172.10.0.0/16"
  local_subnets         = ["172.10.1.0/24"]

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  # Kubernetes cluster configuration (referencia al recurso creado arriba)
  k8s_cluster = {
    name      = volterra_k8s_cluster.this.name
    namespace = "system"
  }

  # Use default storage
  default_storage = true

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  depends_on = [
    module.aws_cloud_credentials,
    volterra_k8s_cluster.this
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

#-----------------------------------------------------------
# Namespace F5 XC para los recursos del Load Balancer
#-----------------------------------------------------------

resource "volterra_namespace" "demo" {
  name = "demo-app"
}

#-----------------------------------------------------------
# Origin Pool - apunta al Service K8s dentro del App Stack
#-----------------------------------------------------------

resource "volterra_origin_pool" "nginx" {
  name      = "nginx-demo-pool"
  namespace = volterra_namespace.demo.name

  origin_servers {
    k8s_service {
      service_name = "nginx-demo-svc.default"
      site_locator {
        site {
          name      = module.aws_vpc_site.name
          namespace = "system"
        }
      }
      inside_network = true
    }
  }

  no_tls                 = true
  port                   = 80
  loadbalancer_algorithm = "LB_OVERRIDE_NONE"
  endpoint_selection     = "LOCAL_PREFERRED"

  depends_on = [module.aws_vpc_site]
}

#-----------------------------------------------------------
# HTTP Load Balancer - expuesto en internet via F5 XC
# Accede via: curl -H "Host: nginx-demo.example.com" <CNAME>
#-----------------------------------------------------------

resource "volterra_http_loadbalancer" "nginx" {
  name      = "nginx-demo-lb"
  namespace = volterra_namespace.demo.name

  domains = ["nginx-demo.example.com"]

  advertise_on_public_default_vip = true

  default_route_pools {
    pool {
      name      = volterra_origin_pool.nginx.name
      namespace = volterra_namespace.demo.name
    }
    weight   = 1
    priority = 1
  }

  http {
    dns_volterra_managed = false
    port                 = "80"
  }

  no_challenge        = true
  disable_waf         = true
  no_service_policies = true
  disable_rate_limit  = true
  round_robin         = true

  depends_on = [volterra_origin_pool.nginx]
}
