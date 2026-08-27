variable "project_name" {
  description = "Prefixo usado no nome/tags de todos os recursos"
  type        = string
  default     = "infra-lab"
}

variable "environment" {
  description = "Ambiente (dev, homolog, prod)"
  type        = string
  default     = "dev"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "AWS session token"
  type        = string
  sensitive   = true
  default     = ""
}
