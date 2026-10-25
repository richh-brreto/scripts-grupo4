variable "project_name" {
  type    = string
  default = "boost"
}

variable "bronze_bucket" {
  description = "Nome do bucket bronze (o mesmo configurado no Fluent Bit)"
  type        = string
}

variable "silver_bucket" {
  description = "Nome do bucket silver"
  type        = string
}

variable "gold_bucket" {
  description = "Nome do bucket gold (resultados do Athena)"
  type        = string
}

variable "agendamento_ativo" {
  description = "true = workflow roda a cada 6 horas; false = só manual"
  type        = bool
  default     = true
}

variable "gerenciar_retencao_bronze" {
  description = "Cria a regra de retenção de logs/ no bronze. ATENÇÃO: substitui todas as regras de lifecycle já existentes no bucket"
  type        = bool
  default     = true
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_session_token" {
  type      = string
  sensitive = true
  default   = ""
}
