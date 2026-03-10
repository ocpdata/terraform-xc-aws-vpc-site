# Ingress Gateway en AWS VPC Site (Single AZ) — F5 XC Cloud

## ¿Qué hace este ejemplo?

Este ejemplo despliega un **Ingress Gateway** de F5 Distributed Cloud (XC) dentro de una VPC nueva en AWS. Su propósito es conectar tu infraestructura en AWS con la red global de F5 XC para que **todo el tráfico entrante a tus aplicaciones pase primero por los servicios de seguridad y entrega de F5 XC** (WAF, protección DDoS, balanceo de carga, etc.) antes de llegar a tus workloads.

## ¿Qué problema resuelve?

Sin esta configuración, tus aplicaciones en AWS están expuestas directamente a internet y debes gestionar la seguridad de forma individual en cada aplicación.

Con el Ingress Gateway, todo el tráfico entrante fluye primero a través de la red global de F5 XC y llega al nodo gateway desplegado en tu VPC:

```
Usuario en cualquier parte del mundo
              │
              ▼
  ┌─────────────────────────────┐
  │      Red Global F5 XC       │  ← WAF, DDoS, balanceo de carga, observabilidad
  │  (PoPs en América/Europa/Asia)│
  └──────────────┬──────────────┘
                 │  tráfico ya inspeccionado y filtrado
                 ▼
  ┌──────────────────────────────────────┐
  │           Tu VPC en AWS              │
  │  ┌──────────────────────────────┐    │
  │  │  Nodo Ingress Gateway        │    │  ← instancia EC2 gestionada por F5 XC
  │  │  (us-east-1a / 172.10.0.0/16)│    │
  │  └───────────────┬──────────────┘    │
  │                  │                   │
  │  ┌───────────────▼──────────────┐    │
  │  │  Tus aplicaciones            │    │  ← subnet local 172.10.1.0/24
  │  │  (workloads protegidos)      │    │
  │  └──────────────────────────────┘    │
  └──────────────────────────────────────┘
```

Esto te da visibilidad y control centralizado de todo el tráfico entrante desde la consola de F5 XC, sin necesidad de modificar la arquitectura existente de tus aplicaciones.

## ¿Qué recursos se crean en AWS?

| Recurso AWS                  | Descripción                                                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **VPC**                      | VPC nueva con CIDR `172.10.0.0/16`                                                                                |
| **Subnet local**             | Una subnet (`172.10.1.0/24`) en `us-east-1a` donde viven tus workloads                                            |
| **Security Group `outside`** | Permite tráfico entrante desde los PoPs globales de F5 XC (TCP 80, TCP 443, UDP 4500) usando Managed Prefix Lists |
| **Security Group `inside`**  | Permite todo el tráfico interno entre recursos de la VPC                                                          |
| **Managed Prefix Lists**     | Tres listas con los rangos IP públicos de F5 XC (Américas, Europa, Asia) para TCP 80/443 y UDP 4500               |
| **Route Tables**             | Tablas de rutas para la subnet local                                                                              |
| **Instancia EC2**            | Nodo master del gateway, gestionado automáticamente por F5 XC                                                     |
| **AWS Cloud Credentials**    | Credenciales IAM registradas en F5 XC para que pueda gestionar recursos AWS                                       |

### ¿Por qué el security group tiene rangos de Américas, Europa y Asia?

El nodo gateway en tu VPC necesita aceptar conexiones entrantes desde **cualquier PoP de F5 XC del mundo**, no solo los de tu región. Esto se debe a que el tráfico puede ingresar por el PoP más cercano al usuario final:

```
Usuario en Frankfurt
    │
    ▼
PoP de F5 XC en Europa  ← IP de rango europeo
    │
    ▼
Tu nodo en us-east-1    ← debe aceptar esa IP aunque el nodo esté en América
```

Por eso el security group abre los puertos TCP 80, TCP 443 y UDP 4500 hacia las tres regiones. Los **Managed Prefix Lists** agrupan eficientemente todos esos rangos para evitar crear una regla por cada CIDR individualmente.

> **Nota sobre límites de AWS:** cada entrada en un Managed Prefix List cuenta como una regla efectiva en el security group. Este ejemplo genera aproximadamente **~109 reglas** (36 CIDRs TCP 80 + 36 CIDRs TCP 443 + 35 CIDRs UDP 4500 + 2 reglas base). El límite por defecto de AWS es **60 reglas**. **Antes de ejecutar `terraform apply`, solicita un aumento a 150 o más** en:
>
> **AWS Console → Service Quotas → Amazon VPC → Inbound or outbound rules per security group**

## ¿Cuándo usar este ejemplo?

| Escenario                                                     | ¿Usar este ejemplo?                              |
| ------------------------------------------------------------- | ------------------------------------------------ |
| Solo necesitas controlar tráfico **entrante** en una única AZ | ✅ Sí                                            |
| Necesitas controlar tráfico **entrante y saliente**           | ❌ Usa `aws-vpc-site-ingress-egress-gw`          |
| Necesitas **alta disponibilidad** con múltiples AZs           | ❌ Usa `aws-vpc-site-ingress-egress-gw-multi-az` |
| Ya tienes una **VPC existente** en AWS                        | ❌ Usa `aws-vpc-site-ingress-gw-existing-vpc`    |

## Requisitos previos

Antes de ejecutar este ejemplo necesitas:

1. **Terraform** >= 1.0 instalado localmente
2. **Credenciales de AWS** con permisos para crear VPCs, subnets, security groups, Managed Prefix Lists y recursos IAM
3. **Cuota de AWS aumentada**: al menos **150 reglas por security group** (ver nota arriba)
4. **Cuenta en F5 XC** con un certificado de API (`.p12`) descargado desde:
   `Administration → Credentials → Add Credentials`
5. **La contraseña del `.p12`** que configuraste al generar el certificado

## Inicio rápido

### 1. Configura tus credenciales

Copia el archivo de ejemplo y edítalo con tus valores reales:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
# terraform.tfvars
aws_access_key  = "AKIA..."
aws_secret_key  = "tu_aws_secret_key"
xc_api_url      = "https://tu-tenant.console.ves.volterra.io/api"
xc_api_p12_file = "./tu-certificado.p12"

# Opcional: personaliza los rangos de red (valores por defecto mostrados)
vpc_cidr      = "172.10.0.0/16"
local_subnets = ["172.10.1.0/24"]
```

Copia tu archivo `.p12` a este directorio y exporta su contraseña como variable de entorno:

```bash
export VES_P12_PASSWORD="tu_contraseña_del_p12"
```

> **Seguridad:** `terraform.tfvars` está incluido en `.gitignore`. Nunca lo subas al repositorio — contiene credenciales sensibles.

### 2. Inicializa y despliega

```bash
terraform init
terraform plan   # revisa qué va a crear antes de aplicar
terraform apply  # despliega la infraestructura
```

El despliegue tarda varios minutos mientras F5 XC registra y activa el site.

### 3. Verifica los outputs

Una vez completado, Terraform mostrará información útil:

```
site_name                = "aws-example-ingress-gw"
master_public_ip_address = "x.x.x.x"
vpc_id                   = "vpc-xxxxxxxxxxxxxxxxx"
local_subnet_ids         = ["subnet-xxxxxxxxxxxxxxxxx"]
```

### 4. Destruye los recursos cuando termines

```bash
terraform destroy
```

## Uso como módulo

Si quieres reutilizar este patrón en tu propio código:

```hcl
module "aws_vpc_site_ingress_gw" {
  source  = "f5devcentral/aws-vpc-site/xc"
  version = "0.0.12"

  site_name             = "aws-example-ingress-gw"
  aws_region            = "us-east-1"
  site_type             = "ingress_gw"
  master_nodes_az_names = ["us-east-1a"]  # una sola AZ
  vpc_cidr              = "172.10.0.0/16"
  local_subnets         = ["172.10.1.0/24"]

  aws_cloud_credentials_name = module.aws_cloud_credentials.name
  block_all_services         = false

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }

  depends_on = [module.aws_cloud_credentials]
}

module "aws_cloud_credentials" {
  source  = "f5devcentral/aws-cloud-credentials/xc"
  version = "0.0.4"

  name           = "aws-example-creds-ingress"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}
```

## Variables

| Variable          | Descripción                                       | Tipo           | Valor por defecto                                             |
| ----------------- | ------------------------------------------------- | -------------- | ------------------------------------------------------------- |
| `xc_api_url`      | URL de la API de F5 XC Cloud                      | `string`       | `"https://your_xc-cloud_api_url.console.ves.volterra.io/api"` |
| `xc_api_p12_file` | Ruta al certificado `.p12` de F5 XC               | `string`       | `"./api-certificate.p12"`                                     |
| `aws_access_key`  | AWS Access Key ID                                 | `string`       | `null`                                                        |
| `aws_secret_key`  | AWS Secret Access Key (sensitive)                 | `string`       | `null`                                                        |
| `vpc_cidr`        | Bloque CIDR de la VPC nueva que se creará en AWS  | `string`       | `"172.10.0.0/16"`                                             |
| `local_subnets`   | Lista con el CIDR de la subnet local (una por AZ) | `list(string)` | `["172.10.1.0/24"]`                                           |

## Outputs

| Nombre                      | Descripción                                                 |
| --------------------------- | ----------------------------------------------------------- |
| `site_name`                 | Nombre del AWS VPC Site registrado en F5 XC                 |
| `site_id`                   | ID del AWS VPC Site en F5 XC                                |
| `master_public_ip_address`  | IP pública del nodo master (útil para diagnóstico)          |
| `ssh_public_key`            | Clave pública SSH generada para el nodo                     |
| `vpc_id`                    | ID de la VPC creada en AWS                                  |
| `local_subnet_ids`          | IDs de las subnets locales creadas                          |
| `outside_security_group_id` | ID del security group externo (tráfico desde PoPs de F5 XC) |
| `local_route_table_ids`     | IDs de las tablas de rutas de la subnet local               |

## Requerimientos

| Nombre                                                                           | Versión    |
| -------------------------------------------------------------------------------- | ---------- |
| [terraform](https://www.terraform.io/)                                           | >= 1.0     |
| [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)              | >= 6.9.0   |
| [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |

## Providers

| Nombre                                                                           | Versión    |
| -------------------------------------------------------------------------------- | ---------- |
| [volterra](https://registry.terraform.io/providers/volterraedge/volterra/latest) | >= 0.11.44 |
| [aws](https://registry.terraform.io/providers/hashicorp/aws/latest)              | >= 6.9.0   |
