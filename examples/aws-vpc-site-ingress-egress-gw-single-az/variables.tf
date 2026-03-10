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

variable "vpc_cidr" {
  type    = string
  default = "172.10.0.0/16"
}

variable "outside_subnets" {
  type    = list(string)
  default = ["172.10.11.0/24"]
}

variable "workload_subnets" {
  type    = list(string)
  default = ["172.10.21.0/24"]
}

variable "inside_subnets" {
  type    = list(string)
  default = ["172.10.31.0/24"]
}
