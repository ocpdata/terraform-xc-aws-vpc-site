# Ingress/Egress Gateway en AWS VPC Site (Multi-AZ) — F5 XC Cloud

## ¿Qué hace este ejemplo?

Este ejemplo despliega un **Ingress/Egress Gateway de alta disponibilidad** de F5 Distributed Cloud (XC) en AWS, distribuido en **3 zonas de disponibilidad**. A diferencia del ejemplo single-AZ, este modo garantiza que si una AZ falla, el servicio continúa operando sin interrupciones.

Además de controlar el tráfico entrante y saliente, conecta tu VPC a la **red global privada de F5 XC (VolterraNet)** para comunicación segura con otras nubes u on-premise.

## ¿Qué problema resuelve?

| Problema                                       | Solución                                                        |
| ---------------------------------------------- | --------------------------------------------------------------- |
| Aplicaciones expuestas directamente a internet | El tráfico pasa primero por F5 XC (WAF, DDoS, etc.)             |
| Sin control del tráfico saliente               | El gateway inspecciona y filtra también el egress               |
| Conectar AWS con Azure, GCP u on-premise       | La Global Virtual Network crea un túnel privado por VolterraNet |
| Single point of failure en una sola AZ         | 3 nodos en 3 AZs independientes con failover automático         |

## Topología

```
                    Internet / Usuarios
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │        Red Global F5 XC             │
         │  WAF · DDoS · Balanceo · Visibilidad │
         └──────┬──────────┬──────────┬────────┘
                │          │          │
                ▼          ▼          ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │                  AWS VPC  172.10.0.0/16  (us-east-1)            │
  │                                                                  │
  │      us-east-1a          us-east-1b          us-east-1c         │
  │   outside-subnet       outside-subnet       outside-subnet      │
  │   172.10.11.0/24       172.10.12.0/24       172.10.13.0/24      │
  │         │                    │                    │             │
  │  ┌──────┴────────────────────┴────────────────────┴──────┐      │
  │  │   NLB interno (creado por F5 XC — no en tf state)    │      │
  │  └──────┬────────────────────┬────────────────────┬──────┘      │
  │         │                    │                    │             │
  │   ┌─────▼────┐         ┌─────▼────┐         ┌─────▼────┐       │
  │   │  Nodo    │         │  Nodo    │         │  Nodo    │       │
  │   │ Master   │         │ Master   │         │ Master   │       │
  │   │  EC2     │         │  EC2     │         │  EC2     │       │
  │   └─────┬────┘         └─────┬────┘         └─────┬────┘       │
  │         │                    │                    │             │
  │   inside-subnet        inside-subnet        inside-subnet      │
  │   172.10.31.0/24       172.10.32.0/24       172.10.33.0/24      │
  │         │                    │                    │             │
  │   workload-subnet      workload-subnet      workload-subnet     │
  │   172.10.21.0/24       172.10.22.0/24       172.10.23.0/24      │
  │   (tus apps)           (tus apps)           (tus apps)         │
  │                                                                  │
  │  Global Virtual Network ────────────────────────────────────── ►│──► Azure / GCP / On-premise
  └──────────────────────────────────────────────────────────────────┘
```

## ¿Qué recursos se crean?

### Recursos creados por Terraform (visibles en el state)

| Recurso AWS                   | Cantidad | Descripción                                              |
| ----------------------------- | -------- | -------------------------------------------------------- |
| `aws_vpc`                     | 1        | VPC con CIDR `172.10.0.0/16`                             |
| `aws_subnet` outside          | 3        | Una por AZ — tráfico entrante desde F5 XC                |
| `aws_subnet` inside           | 3        | Una por AZ — tráfico saliente y conectividad VolterraNet |
| `aws_subnet` workload         | 3        | Una por AZ — donde viven tus aplicaciones                |
| `aws_security_group` outside  | 1        | Permite TCP 80/443 y UDP 4500 desde PoPs F5 XC globales  |
| `aws_security_group` inside   | 1        | Permite tráfico interno de la VPC                        |
| `aws_ec2_managed_prefix_list` | 3        | Rangos IP de F5 XC: Américas, Europa y Asia              |
| `aws_internet_gateway`        | 1        | Para las outside subnets                                 |
| `volterra_aws_vpc_site`       | 1        | Site registrado en F5 XC                                 |
| `volterra_virtual_network`    | 1        | Global VN para conectividad multi-cloud                  |
| `volterra_cloud_credentials`  | 1        | Credenciales IAM en F5 XC                                |

### Recursos creados por F5 XC directamente en tu cuenta AWS (fuera del state)

| Recurso AWS                             | Descripción                                                                                                                                                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Network Load Balancer (NLB) interno** | F5 XC lo crea automáticamente en las 3 outside subnets para distribuir el tráfico entre los nodos master. No aparece en el Terraform state porque F5 XC lo gestiona internamente via `volterra_tf_params_action`. |
| **Instancias EC2** (nodos master × 3)   | Una por AZ, gestionadas por F5 XC                                                                                                                                                                                 |

> **¿Por qué el NLB no está en el state?** El recurso `volterra_tf_params_action` le indica a F5 XC que ejecute su propio proceso de despliegue en tu cuenta AWS. Los recursos que ese proceso crea (NLB, EC2, etc.) son gestionados por F5 XC, no por este módulo.

## Flujo del tráfico

| Dirección              | Ruta completa                                                              |
| ---------------------- | -------------------------------------------------------------------------- |
| **Entrante (ingress)** | Internet → Red F5 XC → NLB outside → Nodo EC2 → workload subnet → tus apps |
| **Saliente (egress)**  | tus apps → workload subnet → Nodo EC2 → inside subnet → VolterraNet        |
| **Multi-cloud**        | inside subnet → Global Virtual Network → Azure / GCP / on-premise          |

## Alta disponibilidad

F5 XC monitoriza continuamente los 3 nodos. Si una AZ falla:

```
Situación normal:          Fallo de us-east-1b:

F5 XC                      F5 XC
  ├──► Nodo 1a ✅             ├──► Nodo 1a ✅  ← absorbe más tráfico
  ├──► Nodo 1b ✅             ├──► Nodo 1b ❌  ← excluido automáticamente
  └──► Nodo 1c ✅             └──► Nodo 1c ✅  ← absorbe más tráfico
```

El failover es **automático y sin intervención manual**.

## ¿Cuándo usar este ejemplo?

| Escenario                                           | ¿Usar este ejemplo?                               |
| --------------------------------------------------- | ------------------------------------------------- |
| Solo tráfico **entrante**, sin HA                   | ❌ Usa `aws-vpc-site-ingress-gw`                  |
| Ingress/Egress en **una sola AZ** (menor costo)     | ❌ Usa `aws-vpc-site-ingress-egress-gw-single-az` |
| Ingress/Egress con **alta disponibilidad** en 3 AZs | ✅ Sí                                             |
| Conectar AWS con otras nubes u on-premise vía F5 XC | ✅ Sí                                             |
| Ya tienes una **VPC existente** en AWS              | ❌ Usa `aws-vpc-site-ingress-gw-existing-vpc`     |

## Requisitos previos

1. **Terraform** >= 1.0 instalado localmente
2. **Credenciales de AWS** con permisos para crear VPCs, subnets, security groups, Managed Prefix Lists, Internet Gateways y recursos IAM
3. **Cuota de AWS aumentada**: al menos **150 reglas por security group** (el límite default es 60; este ejemplo genera ~109 reglas)
   - **AWS Console → Service Quotas → Amazon VPC → Inbound or outbound rules per security group**
4. **Cuenta en F5 XC** con certificado de API (`.p12`) desde:
   `Administration → Credentials → Add Credentials`
5. **Contraseña del `.p12`** que configuraste al generarlo

## Inicio rápido

### 1. Configura tus credenciales

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
vpc_cidr         = "172.10.0.0/16"
outside_subnets  = ["172.10.11.0/24", "172.10.12.0/24", "172.10.13.0/24"]
workload_subnets = ["172.10.21.0/24", "172.10.22.0/24", "172.10.23.0/24"]
inside_subnets   = ["172.10.31.0/24", "172.10.32.0/24", "172.10.33.0/24"]
```

```bash
export VES_P12_PASSWORD="tu_contraseña_del_p12"
```

> **Seguridad:** `terraform.tfvars` está en `.gitignore`. Nunca lo subas al repositorio.

### 2. Inicializa y despliega

```bash
terraform init
terraform plan
terraform apply
```

El despliegue tarda varios minutos: Terraform crea la infraestructura de red, luego F5 XC despliega los 3 nodos EC2 y el NLB en tu cuenta AWS.

### 3. Verifica los outputs

```
site_name                = "aws-example-ingress-egress-gw-az"
master_public_ip_address = "x.x.x.x"
vpc_id                   = "vpc-xxxxxxxxxxxxxxxxx"
outside_subnet_ids       = ["subnet-xxx", "subnet-yyy", "subnet-zzz"]
inside_subnet_ids        = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
workload_subnet_ids      = ["subnet-ddd", "subnet-eee", "subnet-fff"]
```

### 4. Destruye los recursos cuando termines

```bash
terraform destroy
```

## Uso como módulo

Si quieres reutilizar este patrón en tu propio código:

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

## Variables

| Variable           | Descripción                                  | Tipo           | Valor por defecto                                        |
| ------------------ | -------------------------------------------- | -------------- | -------------------------------------------------------- |
| `xc_api_url`       | URL de la API de F5 XC Cloud                 | `string`       | `"https://your_xc-cloud_api_url..."`                     |
| `xc_api_p12_file`  | Ruta al certificado `.p12` de F5 XC          | `string`       | `"./api-certificate.p12"`                                |
| `aws_access_key`   | AWS Access Key ID                            | `string`       | `null`                                                   |
| `aws_secret_key`   | AWS Secret Access Key (sensitive)            | `string`       | `null`                                                   |
| `vpc_cidr`         | Bloque CIDR de la VPC                        | `string`       | `"172.10.0.0/16"`                                        |
| `outside_subnets`  | CIDRs de las 3 subnets outside (una por AZ)  | `list(string)` | `["172.10.11.0/24", "172.10.12.0/24", "172.10.13.0/24"]` |
| `workload_subnets` | CIDRs de las 3 subnets workload (una por AZ) | `list(string)` | `["172.10.21.0/24", "172.10.22.0/24", "172.10.23.0/24"]` |
| `inside_subnets`   | CIDRs de las 3 subnets inside (una por AZ)   | `list(string)` | `["172.10.31.0/24", "172.10.32.0/24", "172.10.33.0/24"]` |

## Outputs

| Nombre                      | Descripción                          |
| --------------------------- | ------------------------------------ |
| `site_name`                 | Nombre del AWS VPC Site en F5 XC     |
| `site_id`                   | ID del AWS VPC Site en F5 XC         |
| `master_public_ip_address`  | IP pública del nodo master principal |
| `ssh_public_key`            | Clave pública SSH de los nodos       |
| `vpc_id`                    | ID de la VPC creada                  |
| `outside_subnet_ids`        | IDs de las 3 subnets outside         |
| `inside_subnet_ids`         | IDs de las 3 subnets inside          |
| `workload_subnet_ids`       | IDs de las 3 subnets workload        |
| `outside_security_group_id` | ID del security group externo        |

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
