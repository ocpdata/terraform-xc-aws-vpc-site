# Ingress Gateway en AWS VPC Site con Single AZ para F5 XC Cloud

## ¿Qué hace este ejemplo?

Este ejemplo despliega un **Ingress Gateway** de F5 Distributed Cloud (XC) dentro de una VPC de AWS. Su propósito es conectar tu infraestructura en AWS con la red global de F5 XC para que **todo el tráfico entrante a tus aplicaciones pase primero por los servicios de seguridad y entrega de F5 XC** (WAF, protección DDoS, balanceo de carga, etc.) antes de llegar a tus workloads.

## ¿Qué problema resuelve?

Sin esta configuración, tus aplicaciones en AWS están expuestas directamente a internet y debes gestionar la seguridad de forma individual en cada aplicación.

Con el Ingress Gateway, todo el tráfico entrante fluye primero por la red global de F5 XC:

```
Internet
    │
    ▼
Red Global F5 XC  ← WAF, protección DDoS, balanceo de carga
    │
    ▼
Nodo Ingress Gateway  ← nodo master desplegado en tu VPC de AWS
    │
    ▼
Tus aplicaciones  ← protegidas, en la subnet local
```

Esto te da visibilidad y control centralizado de todo el tráfico entrante desde la consola de F5 XC, sin necesidad de modificar la arquitectura existente de tus aplicaciones.

## ¿Cuándo usar este ejemplo?

| Escenario                                        | ¿Usar este ejemplo?                              |
| ------------------------------------------------ | ------------------------------------------------ |
| Solo necesitas controlar tráfico **entrante**    | ✅ Sí                                            |
| Necesitas controlar tráfico entrante y saliente  | ❌ Usa `aws-vpc-site-ingress-egress-gw`          |
| Necesitas múltiples AZs para alta disponibilidad | ❌ Usa `aws-vpc-site-ingress-egress-gw-multi-az` |
| Ya tienes una VPC existente en AWS               | ❌ Usa `aws-vpc-site-ingress-gw-existing-vpc`    |

## Requisitos previos

Antes de ejecutar este ejemplo necesitas:

1. **Terraform** >= 1.0 instalado localmente
2. **Credenciales de AWS** con permisos para crear VPCs, subnets, security groups y recursos IAM
3. **Cuenta en F5 XC** con un certificado de API (`.p12`) descargado desde:
   `Administration → Credentials → Add Credentials`
4. **La contraseña del `.p12`** que configuraste al generar el certificado

## Inicio rápido

### 1. Configura tus credenciales

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus valores reales:

```hcl
aws_access_key  = "AKIA..."
aws_secret_key  = "tu_aws_secret"
xc_api_url      = "https://tu-tenant.console.ves.volterra.io/api"
xc_api_p12_file = "./tu-certificado.p12"
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
terraform apply  # despliega
```

### 3. Destruye los recursos cuando termines

```bash
terraform destroy
```

> **Tip:** Si recibes el error `RulesPerSecurityGroupLimitExceeded` en AWS, el límite de reglas por security group de tu cuenta (por defecto: 60) es demasiado bajo. Solicita un aumento en **AWS Service Quotas → Amazon VPC → Inbound or outbound rules per security group** (recomendado: 150 o más).

## Uso

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

## Arquitectura

Este ejemplo crea los siguientes recursos:

- **VPC**: Nueva VPC en AWS con el bloque CIDR especificado
- **Subnet local**: Subnet en una sola AZ donde viven tus workloads
- **Security Groups**: Security groups gestionados para controlar el tráfico de entrada
- **F5 XC Site**: Nodo master de ingress gateway en una sola AZ, registrado en F5 XC Cloud
- **Route Tables**: Tablas de rutas locales para el enrutamiento interno de la subnet
- **AWS Cloud Credentials**: Credenciales IAM registradas en F5 XC para que pueda gestionar recursos de AWS

## Variables

| Variable                     | Descripción                                         | Valor por defecto |
| ---------------------------- | --------------------------------------------------- | ----------------- |
| `site_name`                  | Nombre del AWS VPC Site                             | Requerido         |
| `aws_region`                 | Región de AWS donde se despliega                    | Requerido         |
| `site_type`                  | Tipo de site (debe ser `"ingress_gw"`)              | Requerido         |
| `master_nodes_az_names`      | Lista con la zona de disponibilidad del nodo master | Requerido         |
| `local_subnets`              | CIDR de la subnet local (se requiere 1)             | Requerido         |
| `vpc_cidr`                   | CIDR de la VPC                                      | Requerido         |
| `aws_cloud_credentials_name` | Nombre de las credenciales de AWS en F5 XC          | Requerido         |
| `block_all_services`         | Bloquear todos los servicios en el site             | `false`           |

## Outputs

| Nombre                      | Descripción                          |
| --------------------------- | ------------------------------------ |
| `site_name`                 | Nombre del AWS VPC Site configurado  |
| `site_id`                   | ID del AWS VPC Site configurado      |
| `master_public_ip_address`  | Dirección IP pública del nodo master |
| `vpc_id`                    | ID de la VPC creada                  |
| `local_subnet_ids`          | IDs de las subnets locales           |
| `outside_security_group_id` | ID del security group outside        |
| `local_route_table_ids`     | IDs de las tablas de rutas locales   |

## Requerimientos

| Nombre                                                                                                               | Versión    |
| -------------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="requirement_terraform"></a> [terraform](https://www.terraform.io/)                                          | >= 1.0     |
| <a name="requirement_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 6.9.0   |
| <a name="requirement_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |

## Providers

| Nombre                                                                                                            | Versión    |
| ----------------------------------------------------------------------------------------------------------------- | ---------- |
| <a name="provider_volterra"></a> [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |
| <a name="provider_aws"></a> [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)                   | >= 6.9.0   |
