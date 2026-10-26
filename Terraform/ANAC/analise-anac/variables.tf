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
  description = "Bucket bronze com as partes da ANAC enviadas pela Lambda (combinadaYYYY-MM/)"
  type        = string
}

variable "silver_bucket" {
  description = "Bucket silver que recebe o agregado (voos_brasil_paises_ingleses/) e o script do Glue (_glue/)"
  type        = string
}

variable "gold_bucket" {
  description = "Bucket onde o Athena grava os resultados das consultas (prefixo _athena-results/analise/)"
  type        = string
}

variable "database_name" {
  description = "Database do Glue Data Catalog (os .sql em ../code/Athena usam boost_analise)"
  type        = string
  default     = "boost_analise"
}

variable "glue_role_name" {
  description = "Role usada pelo job (no AWS Academy só existe a LabRole)"
  type        = string
  default     = "LabRole"
}

variable "glue_script_path" {
  description = "Caminho local do job bronze -> silver da ANAC"
  type        = string
  default     = "../code/Glue/glue_bronze_para_silver.py"
}

variable "athena_sql_dir" {
  description = "Pasta local com as subpastas views/ e consultas/ (.sql)"
  type        = string
  default     = "../code/Athena"
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
