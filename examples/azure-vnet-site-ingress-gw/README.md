# Ingress Gateway en Azure VNet Site con Single Zone para F5 XC Cloud

## ¿Qué hace este ejemplo?

Este ejemplo despliega un **Ingress Gateway** de F5 Distributed Cloud (XC) dentro de una VNet de Azure. Es el equivalente directo del ejemplo [`aws-vpc-site-ingress-gw`](../aws-vpc-site-ingress-gw) pero sobre infraestructura Azure.

Su propósito es conectar tu infraestructura en Azure con la red global de F5 XC para que **todo el tráfico entrante a tus aplicaciones pase primero por los servicios de seguridad y entrega de F5 XC** (WAF, protección DDoS, balanceo de carga, etc.) antes de llegar a tus workloads.

```
Internet
    │
    ▼
Red Global F5 XC  ← WAF, protección DDoS, balanceo de carga
    │
    ▼
Nodo Ingress Gateway  ← nodo CE desplegado en tu VNet de Azure (zona 1)
    │
    ▼
Tus aplicaciones  ← protegidas, en la subnet local
```

## ¿Qué crea este ejemplo?

| Recurso                 | Tipo Terraform               | Descripción                                      |
| ----------------------- | ---------------------------- | ------------------------------------------------ |
| SSH Key                 | `tls_private_key`            | Par de claves RSA 4096 generado automáticamente  |
| Azure Credentials en XC | `volterra_cloud_credentials` | Service Principal de Azure registrado en F5 XC   |
| Azure VNet Site         | `volterra_azure_vnet_site`   | Site de tipo `ingress_gw` registrado en F5 XC    |
| Site Labels             | `volterra_cloud_site_labels` | Tags aplicados al site en XC                     |
| Deploy del nodo CE      | `volterra_tf_params_action`  | Desencadena el despliegue real del nodo en Azure |

F5 XC gestiona automáticamente la creación de los recursos de red Azure (VNet, subnet, NSG, route tables) dentro del Resource Group especificado.

## Diferencias con el equivalente AWS

| Concepto               | AWS (`aws-vpc-site-ingress-gw`) | Azure (este ejemplo)                           |
| ---------------------- | ------------------------------- | ---------------------------------------------- |
| Provider cloud         | `hashicorp/aws`                 | `hashicorp/azurerm`                            |
| Recurso de site XC     | `volterra_aws_vpc_site`         | `volterra_azure_vnet_site`                     |
| `site_kind` en action  | `aws_vpc_site`                  | `azure_vnet_site`                              |
| Red                    | VPC + CIDR                      | VNet + `primary_ipv4`                          |
| Zona                   | `us-east-1a`                    | `"1"` (número)                                 |
| Tipo de HW certificado | `aws-byol-voltmesh`             | `azure-byol-voltmesh`                          |
| Credenciales cloud     | IAM Access Key + Secret         | Service Principal (tenant/subscription/client) |
| Agrupación de recursos | No existe                       | Resource Group (requerido)                     |
| Región                 | `us-east-1`                     | `eastus`                                       |
| Tipo de instancia      | `t3.xlarge`                     | `Standard_D3_v2`                               |

## Requisitos previos

1. **Terraform** >= 1.0 instalado localmente
2. **Cuenta Azure** con un Service Principal que tenga rol `Contributor` en la suscripción
3. **Cuenta en F5 XC** con un certificado de API (`.p12`) descargado desde:
   `Administration → Credentials → Add Credentials`
4. **La contraseña del `.p12`** que configuraste al generar el certificado

### Crear el Service Principal en Azure

```bash
az ad sp create-for-rbac \
  --name "f5xc-ingress-gw" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

El comando devuelve los valores que necesitarás:

```json
{
  "appId": "→ azure_client_id",
  "password": "→ azure_client_secret",
  "tenant": "→ azure_tenant_id"
}
```

El `azure_subscription_id` lo encontras en el portal de Azure o con `az account show`.

## Inicio rápido

### 1. Configura tus credenciales

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus valores reales:

```hcl
azure_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_secret   = "tu_client_secret"
xc_api_url            = "https://tu-tenant.console.ves.volterra.io/api"
xc_api_p12_file       = "./tu-certificado.p12"
```

Copia tu archivo `.p12` a este directorio y exporta la contraseña:

```bash
export VES_P12_PASSWORD="tu_contraseña_del_p12"
```

> **Importante:** `terraform.tfvars` ya está incluido en `.gitignore`. Nunca subas este archivo al repositorio — contiene credenciales sensibles.

### 2. Inicializa y despliega

```bash
terraform init
terraform plan   # revisa qué va a crear
terraform apply  # despliega (puede tardar 15-30 minutos)
```

### 3. Destruye los recursos cuando termines

```bash
terraform destroy
```

## Personalización

Los valores hardcodeados en `main.tf` que puedes adaptar directamente:

| Parámetro            | Valor por defecto             | Descripción                           |
| -------------------- | ----------------------------- | ------------------------------------- |
| `site_name` / `name` | `azure-example-ingress-gw`    | Nombre del site en XC                 |
| `azure_region`       | `eastus`                      | Región de Azure                       |
| `resource_group`     | `azure-example-ingress-gw-rg` | Resource Group creado por XC en Azure |
| `machine_type`       | `Standard_D3_v2`              | Tamaño de VM en Azure                 |
| `azure_az`           | `"1"`                         | Zona de disponibilidad (1, 2 o 3)     |
| `vnet primary_ipv4`  | `172.10.0.0/16`               | CIDR de la VNet                       |
| `local_subnet ipv4`  | `172.10.1.0/24`               | CIDR de la subnet local               |
| `allowed_vip_port`   | `use_http_https_port = true`  | Puertos 80/443 habilitados            |

## Outputs

| Nombre                     | Descripción                            |
| -------------------------- | -------------------------------------- |
| `site_name`                | Nombre del Azure VNet Site configurado |
| `site_id`                  | ID del Azure VNet Site configurado     |
| `master_public_ip_address` | Dirección IP pública del nodo master   |
| `ssh_private_key`          | Clave privada SSH generada (sensible)  |
| `ssh_public_key`           | Clave pública SSH utilizada            |

## Requerimientos

| Nombre                                                                           | Versión    |
| -------------------------------------------------------------------------------- | ---------- |
| [terraform](https://www.terraform.io/)                                           | >= 1.0     |
| [azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest)      | >= 3.0.0   |
| [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |
| [tls](https://registry.terraform.io/providers/hashicorp/tls/latest)              | >= 4.0.0   |
| [time](https://registry.terraform.io/providers/hashicorp/time/latest)            | >= 0.9.0   |
