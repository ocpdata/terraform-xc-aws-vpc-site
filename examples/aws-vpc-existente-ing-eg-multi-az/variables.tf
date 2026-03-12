variable "xc_api_url" {
  type    = string
  default = "https://your_xc-cloud_api_url.console.ves.volterra.io/api"
}

variable "xc_api_p12_file" {
  type    = string
  default = "./api-certificate.p12"
}

variable "aws_access_key" {
  type    = string
  default = null
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
  default   = null
}

variable "vpc_id" {
  description = "ID de la VPC existente en AWS donde se desplegará el sitio F5 XC."
  type        = string
}

variable "existing_outside_subnets" {
  description = "IDs de las subnets outside existentes (una por AZ: us-east-1a, us-east-1b, us-east-1c)."
  type        = list(string)

  validation {
    condition     = length(var.existing_outside_subnets) == 3
    error_message = "Se deben proporcionar exactamente 3 subnet IDs outside, uno por AZ."
  }
}

variable "existing_inside_subnets" {
  description = "IDs de las subnets inside existentes (una por AZ: us-east-1a, us-east-1b, us-east-1c)."
  type        = list(string)

  validation {
    condition     = length(var.existing_inside_subnets) == 3
    error_message = "Se deben proporcionar exactamente 3 subnet IDs inside, uno por AZ."
  }
}

variable "existing_workload_subnets" {
  description = "IDs de las subnets workload existentes (una por AZ: us-east-1a, us-east-1b, us-east-1c)."
  type        = list(string)

  validation {
    condition     = length(var.existing_workload_subnets) == 3
    error_message = "Se deben proporcionar exactamente 3 subnet IDs workload, uno por AZ."
  }
}
