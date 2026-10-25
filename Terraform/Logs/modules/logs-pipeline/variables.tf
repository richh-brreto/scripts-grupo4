variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos recursos do pipeline"
  type        = string
  default     = "boost"
}

variable "bronze_bucket" {
  description = "Bucket bronze onde o Fluent Bit grava os logs (prefixo logs/)"
  type        = string
}

variable "silver_bucket" {
  description = "Bucket silver que recebe os logs tratados em Parquet (prefixo logs/) e o script do Glue (_glue/)"
  type        = string
}

variable "gold_bucket" {
  description = "Bucket onde o Athena grava os resultados das consultas (prefixo _athena-results/logs/)"
  type        = string
}

variable "database_name" {
  description = "Database do Glue Data Catalog (as consultas em Athena/ usam boost_logs)"
  type        = string
  default     = "boost_logs"
}

variable "glue_role_name" {
  description = "Role usada pelo crawler e pelo job (no AWS Academy só existe a LabRole)"
  type        = string
  default     = "LabRole"
}

variable "agendamento" {
  description = "Expressão cron (UTC) do gatilho do workflow"
  type        = string
  default     = "cron(0 */6 * * ? *)"
}

variable "agendamento_ativo" {
  description = "Liga o gatilho agendado (desligado = só execução manual)"
  type        = bool
  default     = true
}

variable "retencao_bronze_dias" {
  description = "Dias até apagar os logs brutos do bronze"
  type        = number
  default     = 180
}

variable "glue_script_path" {
  description = "Caminho local do script logs_bronze_to_silver.py"
  type        = string
}

variable "athena_sql_dir" {
  description = "Pasta local com as subpastas consultas/ e views/ (.sql)"
  type        = string
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
