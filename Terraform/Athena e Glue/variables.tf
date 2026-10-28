variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "bronze_bucket" {
  description = "Bucket S3 onde o Fluent Bit grava os logs (ja existente)"
  type        = string
}

variable "athena_results_bucket" {
  description = "Bucket (novo) para resultados do Athena"
  type        = string
}

variable "glue_database" {
  type    = string
  default = "logs_bronze_dev"
}

variable "crawler_schedule" {
  type    = string
  default = "cron(0 * * * ? *)"
}

variable "instance_ips" {
  description = "IPs privados das instancias que serao monitoradas"
  type        = list(string)
}

variable "lab_role_name" {
  description = "Role existente do Learner Lab (IAM bloqueado)"
  type        = string
  default     = "LabRole"
}

variable "fluentbit_tag_key" {
  type    = string
  default = "fluentbit"
}

variable "fluentbit_tag_value" {
  type    = string
  default = "true"
}

variable "log_path" {
  description = "Caminho dos logs nas instancias"
  type        = string
  default     = "/var/log/app/*.log"
}
