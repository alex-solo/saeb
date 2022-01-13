variable "environment" {
  type = string
}

variable "terraform_script_version" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_containers" {
  description = "Default blob storage containers used by SAEB Platform"
  type        = list(string)
}