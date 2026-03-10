# Ingress/Egress Gateway en AWS VPC Site con Single AZ para F5 XC Cloud

## ¿Qué hace este ejemplo?

Este ejemplo despliega un **Ingress/Egress Gateway** de F5 Distributed Cloud (XC) dentro de una VPC de AWS en una sola zona de disponibilidad. A diferencia del Ingress Gateway simple, este modo controla **tanto el tráfico entrante como el saliente**, y además conecta tu VPC con la **red global privada de F5 XC** para comunicación entre sitios (multi-cloud u on-premise).

## ¿Qué problema resuelve?

Sin esta configuración, tus aplicaciones en AWS solo tienen control sobre el tráfico que entra, y conectar múltiples nubes o una red on-premise requiere soluciones complejas como VPNs o AWS Transit Gateway.

Con el Ingress/Egress Gateway, F5 XC actúa como punto de control completo del tráfico:

```
Internet
    │
    ▼
Outside Subnet (172.10.11.0/24)   ← tráfico entrante desde internet
    │
    ▼
Nodo Gateway F5 XC                ← inspecciona y enruta en ambas direcciones
    │               │
    ▼               ▼
Workload Subnet     Inside Subnet (172.10.31.0/24)
(172.10.21.0/24)    └── tráfico saliente / conectividad privada
tus aplicaciones          │
                          ▼
                  Red Global F5 XC (VolterraNet)
                  └── Azure, GCP, on-premise, otros sitios AWS
```

## ¿Cuándo usar este ejemplo?

| Escenario                                                     | ¿Usar este ejemplo?                              |
| ------------------------------------------------------------- | ------------------------------------------------ |
| Solo necesitas controlar tráfico **entrante**                 | ❌ Usa `aws-vpc-site-ingress-gw`                 |
| Necesitas controlar tráfico **entrante y saliente**           | ✅ Sí                                            |
| Necesitas conectar AWS con otras nubes u on-premise vía F5 XC | ✅ Sí                                            |
| Necesitas múltiples AZs para alta disponibilidad              | ❌ Usa `aws-vpc-site-ingress-egress-gw-multi-az` |
| Ya tienes una VPC existente en AWS                            | ❌ Usa `aws-vpc-site-ingress-gw-existing-vpc`    |

## Diferencia clave respecto a ingress-gw

| Característica                            | ingress-gw | ingress-egress-gw |
| ----------------------------------------- | ---------- | ----------------- |
| Control de tráfico entrante               | ✅         | ✅                |
| Control de tráfico saliente               | ❌         | ✅                |
| Conexión a red global F5 XC (multi-cloud) | ❌         | ✅                |
| Número de subnets                         | 1          | 3                 |
| Costo de infraestructura                  | Menor      | Mayor             |

## Requisitos previos

Antes de ejecutar este ejemplo necesitas:

1. **Terraform** >= 1.0 instalado localmente
2. **Credenciales de AWS** con permisos para crear VPCs, subnets, security groups y recursos IAM
3. **Cuenta en F5 XC** con un certificado de API (`.p12`) descargado desde:
   `Administration → Credentials → Add Credentials`
4. **La contraseña del `.p12`** que configuraste al generar el certificado
5. La **Global Virtual Network** se crea automáticamente con este ejemplo mediante Terraform — no necesitas crearla manualmente

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

Exporta la contraseña del `.p12`:

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
# Crea la Global Virtual Network en F5 XC para conectividad multi-cloud
resource "volterra_virtual_network" "global" {
  name      = "aws-global-vn"
  namespace = "system"

  global_network = true
}

module "aws_vpc_site_ingress_egress_gw_single_az" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-ingress-egress-gw-single-az"
  aws_region            = "us-east-1"
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["us-east-1a"]
  vpc_cidr              = "172.10.0.0/16"

  # Tres subnets requeridas para ingress/egress
  outside_subnets  = ["172.10.11.0/24"]
  workload_subnets = ["172.10.21.0/24"]
  inside_subnets   = ["172.10.31.0/24"]

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
    Environment = "example"
    Purpose     = "ingress-egress-gateway"
    AZs         = "single-az"
  }

  depends_on = [
    module.aws_cloud_credentials,
    volterra_virtual_network.global
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

## Arquitectura

Este ejemplo crea los siguientes recursos:

- **VPC**: Nueva VPC en AWS con el bloque CIDR especificado
- **Outside Subnet** (`172.10.11.0/24`): Recibe el tráfico entrante desde internet
- **Workload Subnet** (`172.10.21.0/24`): Donde viven tus aplicaciones
- **Inside Subnet** (`172.10.31.0/24`): Para tráfico saliente y conectividad privada entre redes
- **Security Groups**: Security groups gestionados para cada subnet
- **F5 XC Site**: Nodo master ingress/egress en una sola AZ, registrado en F5 XC Cloud
- **Global Virtual Network** (`aws-global-vn`): Red virtual global creada en F5 XC (`namespace = system`) que permite conectividad privada con otros sitios
- **Global Network Connection**: Enlace entre la subnet inside del site y la Global Virtual Network (tipo `sli_to_global_dr`)
- **AWS Cloud Credentials**: Credenciales IAM registradas en F5 XC para gestionar recursos de AWS

## Variables

| Variable                          | Descripción                                          | Valor por defecto |
| --------------------------------- | ---------------------------------------------------- | ----------------- |
| `site_name`                       | Nombre del AWS VPC Site                              | Requerido         |
| `aws_region`                      | Región de AWS donde se despliega                     | Requerido         |
| `master_nodes_az_names`           | Lista con la zona de disponibilidad del nodo master  | Requerido         |
| `outside_subnets`                 | CIDR de la subnet outside (se requiere 1)            | Requerido         |
| `inside_subnets`                  | CIDR de la subnet inside (se requiere 1)             | Requerido         |
| `workload_subnets`                | CIDR de la subnet de workloads (se requiere 1)       | Requerido         |
| `global_network_connections_list` | Configuración de conectividad a redes globales F5 XC | `[]`              |
| `block_all_services`              | Bloquear todos los servicios en el site              | `false`           |

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
```
