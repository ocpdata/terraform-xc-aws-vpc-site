variable "xc_api_url" {
  type    = string
  default = "https://your_tenant.console.ves.volterra.io/api"
}

variable "xc_api_p12_file" {
  type    = string
  default = "./api-certificate.p12"
}

#-----------------------------------------------------------
# Azure Service Principal
#-----------------------------------------------------------

variable "azure_tenant_id" {
  description = "Azure Active Directory Tenant ID."
  type        = string
  default     = null
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID."
  type        = string
  default     = null
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID (Application ID)."
  type        = string
  default     = null
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret."
  type        = string
  sensitive   = true
  default     = null
}
