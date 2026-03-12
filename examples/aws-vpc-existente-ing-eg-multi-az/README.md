# AWS VPC Site – Ingress/Egress GW Multi-AZ con VPC Existente

Este ejemplo despliega un **AWS VPC Site en F5 Distributed Cloud** de tipo `ingress_egress_gw` en configuración **multi-AZ** (3 AZs), utilizando una **VPC de AWS ya existente** en lugar de crear una nueva.

## Descripción

A diferencia del ejemplo `aws-vpc-site-ingress-egress-gw-multi-az`, este ejemplo:

- **No crea** una VPC en AWS.
- **Reutiliza** una VPC existente, cuyo ID y subnets se especifican como variables de entrada.
- **Crea** el sitio F5 XC (`volterra_aws_vpc_site`) con los nodos master distribuidos en 3 AZs.
- **Crea** una Global Virtual Network en F5 XC para conectividad multi-cloud.

## Requisitos previos

- Una VPC de AWS ya aprovisionada en `us-east-1`.
- Tres subnets **outside**, tres subnets **inside** y tres subnets **workload** existentes dentro de esa VPC, una por AZ (`us-east-1a`, `us-east-1b`, `us-east-1c`).
- Credenciales de API de F5 Distributed Cloud (archivo `.p12`).
- Credenciales de AWS.

## Variables de entrada

| Variable                    | Descripción                                     |
| --------------------------- | ----------------------------------------------- |
| `vpc_id`                    | ID de la VPC existente en AWS                   |
| `existing_outside_subnets`  | Lista de 3 IDs de subnets outside (una por AZ)  |
| `existing_inside_subnets`   | Lista de 3 IDs de subnets inside (una por AZ)   |
| `existing_workload_subnets` | Lista de 3 IDs de subnets workload (una por AZ) |
| `aws_access_key`            | AWS Access Key ID                               |
| `aws_secret_key`            | AWS Secret Access Key                           |
| `xc_api_url`                | URL de la API de F5 XC                          |
| `xc_api_p12_file`           | Ruta al certificado p12 de F5 XC                |

## Uso

```bash
# Copiar el archivo de ejemplo y rellenar los valores
cp terraform.tfvars.example terraform.tfvars

# Inicializar Terraform
terraform init

# Revisar el plan
terraform plan

# Aplicar
terraform apply
```

## Recursos creados

- `volterra_virtual_network.global` – Global Virtual Network en F5 XC.
- `module.aws_vpc_site` – AWS VPC Site en F5 XC (tipo `ingress_egress_gw`, 3 nodos master).
- `module.aws_cloud_credentials` – Credenciales de nube AWS registradas en F5 XC.
