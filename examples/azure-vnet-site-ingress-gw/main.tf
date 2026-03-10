provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}

provider "azurerm" {
  features {}
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}

#-----------------------------------------------------
# SSH Key
#-----------------------------------------------------

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#-----------------------------------------------------
# Azure Cloud Credentials en F5 XC
# Registra el Service Principal de Azure en el tenant de XC
# para que XC pueda gestionar recursos en la suscripción.
#-----------------------------------------------------

resource "volterra_cloud_credentials" "azure" {
  name      = "azure-example-creds-ingress"
  namespace = "system"

  azure_client_secret {
    tenant_id       = var.azure_tenant_id
    subscription_id = var.azure_subscription_id
    client_id       = var.azure_client_id

    client_secret {
      clear_secret_info {
        # El provider volterra requiere el secreto codificado en base64
        # con el esquema "string:///"
        url = format("string:///%s", base64encode(var.azure_client_secret))
      }
    }
  }
}

#-----------------------------------------------------
# Azure VNet Site en F5 XC
# Equivalente a volterra_aws_vpc_site con site_type = "ingress_gw".
# F5 XC desplegará un nodo CE (Customer Edge) en la zona indicada
# actuando como Ingress Gateway: todo el tráfico entrante pasa
# primero por la red global de F5 XC antes de llegar a tus workloads.
#-----------------------------------------------------

resource "volterra_azure_vnet_site" "this" {
  name      = "azure-example-ingress-gw"
  namespace = "system"

  # Región y Resource Group de Azure donde se desplegará el nodo CE.
  # F5 XC creará el Resource Group si no existe.
  azure_region   = "eastus"
  resource_group = "azure-example-ingress-gw-rg"

  # Tipo de instancia Azure (equivalente a instance_type en AWS)
  machine_type = "Standard_D3_v2"

  os {
    default_os_version = true
  }

  sw {
    default_sw_version = true
  }

  # Requerido por XC: modo de supervivencia offline (one-of)
  offline_survivability_mode {
    no_offline_survivability_mode = true
  }

  # Requerido por XC: streaming de logs (one-of)
  logs_streaming_disabled = true

  # Credenciales Azure registradas en XC (creadas arriba)
  azure_cred {
    name      = volterra_cloud_credentials.azure.name
    namespace = "system"
  }

  # Nueva VNet creada por F5 XC durante el deploy
  # (equivalente a vpc_cidr en AWS)
  vnet {
    new_vnet {
      name         = "azure-example-ingress-gw-vnet"
      primary_ipv4 = "172.10.0.0/16"
    }
  }

  ssh_key = tls_private_key.key.public_key_openssh

  no_worker_nodes    = true
  block_all_services = false

  #-----------------------------------------------------
  # Tipo de site: Ingress Gateway (una sola NIC, una sola zona)
  # azure_certified_hw = "azure-byol-voltmesh"        → single NIC (ingress_gw)
  # azure_certified_hw = "azure-byol-multi-nic-voltmesh" → multi NIC (ingress_egress_gw)
  #-----------------------------------------------------

  ingress_gw {
    azure_certified_hw = "azure-byol-voltmesh"

    # Nodo master en zona "1" de Azure
    # (equivalente a aws_az_name = "us-east-1a" en AWS)
    az_nodes {
      azure_az = "1"

      local_subnet {
        # Subnet local donde viven los workloads, creada por XC
        subnet_param {
          ipv4 = "172.10.1.0/24"
        }
      }
    }
  }

  tags = {
    Environment = "example"
    Purpose     = "ingress-gateway"
  }

  lifecycle {
    ignore_changes = [labels]
  }

  depends_on = [volterra_cloud_credentials.azure]
}

#-----------------------------------------------------
# Labels del site en XC
#-----------------------------------------------------

resource "volterra_cloud_site_labels" "labels" {
  name      = volterra_azure_vnet_site.this.name
  site_type = "azure_vnet_site"
  labels = {
    Environment = "example"
    Purpose     = "ingress-gateway"
  }
  ignore_on_delete = true

  depends_on = [volterra_azure_vnet_site.this]
}

#-----------------------------------------------------
# Espera 30s antes de ejecutar el action_apply
# (mismo patrón que el módulo AWS)
#-----------------------------------------------------

resource "time_sleep" "wait_120_seconds" {
  depends_on      = [volterra_azure_vnet_site.this]
  create_duration = "120s"
}

#-----------------------------------------------------
# Despliegue real del nodo CE en Azure
# site_kind = "azure_vnet_site" (equivalente a "aws_vpc_site")
#-----------------------------------------------------

resource "volterra_tf_params_action" "action_apply" {
  site_name        = volterra_azure_vnet_site.this.name
  site_kind        = "azure_vnet_site"
  action           = "apply"
  wait_for_action  = true
  ignore_on_update = true

  depends_on = [
    volterra_azure_vnet_site.this,
    time_sleep.wait_120_seconds
  ]
}

#-----------------------------------------------------
# Parsear outputs del action_apply (IP pública del nodo, etc.)
#-----------------------------------------------------

locals {
  tf_output = volterra_tf_params_action.action_apply.tf_output
  lines     = split("\n", trimspace(local.tf_output))
  output_map = {
    for line in local.lines :
    trimspace(element(split("=", line), 0)) => jsondecode(trimspace(element(split("=", line), 1)))
    if can(regex("=", line))
  }
}
