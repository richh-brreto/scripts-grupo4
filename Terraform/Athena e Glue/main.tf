terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################
# Variáveis
############################################
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bronze_bucket" {
  description = "Bucket já existente para onde o Fluent Bit envia os logs"
  type        = string
  default     = "infra-lab-bronze-dev"
}

variable "logs_prefix" {
  type    = string
  default = "logs"
}

variable "database_name" {
  type    = string
  default = "infra_lab_logs"
}

variable "crawler_schedule" {
  description = "Cron do crawler (UTC). Vazio = só manual."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

############################################
# Resultados do Athena: usa o bucket bronze (prefixo athena-results/)
# Learner Lab bloqueia a criação de buckets via Terraform (SCP)
############################################
locals {
  athena_results_bucket = var.bronze_bucket
}

############################################
# Glue Database
############################################
resource "aws_glue_catalog_database" "logs" {
  name = var.database_name
}

############################################
# Tabela com Partition Projection (funciona sem crawler)
############################################
resource "aws_glue_catalog_table" "logs_raw" {
  name          = "logs_raw"
  database_name = aws_glue_catalog_database.logs.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification                  = "json"
    compressionType                 = "gzip"
    "projection.enabled"            = "true"
    "projection.year.type"          = "integer"
    "projection.year.range"         = "2024,2035"
    "projection.month.type"         = "integer"
    "projection.month.range"        = "1,12"
    "projection.month.digits"       = "2"
    "projection.day.type"           = "integer"
    "projection.day.range"          = "1,31"
    "projection.day.digits"         = "2"
    "projection.hour.type"          = "integer"
    "projection.hour.range"         = "0,23"
    "projection.hour.digits"        = "2"
    "storage.location.template"     = "s3://${var.bronze_bucket}/${var.logs_prefix}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
  }

  partition_keys {
    name = "year"
    type = "int"
  }
  partition_keys {
    name = "month"
    type = "int"
  }
  partition_keys {
    name = "day"
    type = "int"
  }
  partition_keys {
    name = "hour"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${var.bronze_bucket}/${var.logs_prefix}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "ignore.malformed.json" = "true"
      }
    }

    # Campos gerados pelo Fluent Bit (tail sem parser + record_modifier)
    columns {
      name = "date"
      type = "string"
    }
    columns {
      name = "log"
      type = "string"
    }
    columns {
      name = "host"
      type = "string"
    }
    # Só vem preenchido se você adicionar "Path_Key file" no [INPUT] tail
    columns {
      name = "file"
      type = "string"
    }
  }
}

############################################
# Learner Lab: não dá para criar IAM, usa a LabRole que já existe
############################################
data "aws_iam_role" "lab" {
  name = "LabRole"
}

############################################
# Glue Crawler (cria a tabela "logs" a partir do S3)
############################################
resource "aws_glue_crawler" "logs" {
  name          = "infra-lab-logs-crawler"
  role          = data.aws_iam_role.lab.arn
  database_name = aws_glue_catalog_database.logs.name
  schedule      = var.crawler_schedule == "" ? null : var.crawler_schedule

  s3_target {
    path = "s3://${var.bronze_bucket}/${var.logs_prefix}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

############################################
# Athena Workgroup
############################################
resource "aws_athena_workgroup" "logs" {
  name          = "infra-lab-logs"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10737418240 # 10 GB por query

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${local.athena_results_bucket}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

############################################
# Named Queries (SELECTs prontos)
############################################
locals {
  db = aws_glue_catalog_database.logs.name
}

resource "aws_athena_named_query" "ultimos_logs" {
  name      = "01-ultimos-100-logs-hoje"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT from_iso8601_timestamp("date") AS ts, host, log
    FROM ${local.db}.logs_raw
    WHERE year  = year(current_date)
      AND month = month(current_date)
      AND day   = day(current_date)
    ORDER BY ts DESC
    LIMIT 100;
  SQL
}

resource "aws_athena_named_query" "erros_ultima_hora" {
  name      = "02-erros-ultimas-24h"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT from_iso8601_timestamp("date") AS ts, host, log
    FROM ${local.db}.logs_raw
    WHERE from_iso8601_timestamp("date") > current_timestamp - interval '24' hour
      AND year  >= year(current_date - interval '1' day)
      AND (lower(log) LIKE '%error%'
        OR lower(log) LIKE '%exception%'
        OR lower(log) LIKE '%fatal%'
        OR lower(log) LIKE '%panic%')
    ORDER BY ts DESC
    LIMIT 500;
  SQL
}

resource "aws_athena_named_query" "ssh_falhas" {
  name      = "03-ssh-tentativas-falhas-por-host"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT host,
           regexp_extract(log, 'from ([0-9.]+)', 1) AS ip_origem,
           count(*) AS tentativas
    FROM ${local.db}.logs_raw
    WHERE year = year(current_date) AND month = month(current_date)
      AND (log LIKE '%Failed password%' OR log LIKE '%Invalid user%')
    GROUP BY 1, 2
    ORDER BY tentativas DESC
    LIMIT 50;
  SQL
}

resource "aws_athena_named_query" "volume_por_host" {
  name      = "04-volume-de-logs-por-host-e-hora"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT host, year, month, day, hour, count(*) AS linhas
    FROM ${local.db}.logs_raw
    WHERE year = year(current_date) AND month = month(current_date)
    GROUP BY 1, 2, 3, 4, 5
    ORDER BY year DESC, month DESC, day DESC, hour DESC, linhas DESC;
  SQL
}

resource "aws_athena_named_query" "docker_stderr" {
  name      = "05-docker-containers-stderr"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT from_iso8601_timestamp("date") AS ts,
           host,
           json_extract_scalar(log, '$.log') AS mensagem
    FROM ${local.db}.logs_raw
    WHERE year = year(current_date) AND month = month(current_date)
      AND log LIKE '{"log":%'
      AND json_extract_scalar(log, '$.stream') = 'stderr'
    ORDER BY ts DESC
    LIMIT 200;
  SQL
}

resource "aws_athena_named_query" "cloud_init" {
  name      = "06-cloud-init-output"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    SELECT from_iso8601_timestamp("date") AS ts, host, log
    FROM ${local.db}.logs_raw
    WHERE year = year(current_date) AND month = month(current_date)
      AND (log LIKE '%cloud-init%' OR log LIKE 'Cloud-init%')
    ORDER BY ts DESC
    LIMIT 200;
  SQL
}

resource "aws_athena_named_query" "busca_texto" {
  name      = "07-busca-por-texto-e-host"
  workgroup = aws_athena_workgroup.logs.id
  database  = local.db
  query     = <<-SQL
    -- Troque o host e o texto; sempre filtre por partição (year/month/day) para reduzir custo
    SELECT from_iso8601_timestamp("date") AS ts, host, log
    FROM ${local.db}.logs_raw
    WHERE year = 2026 AND month = 10 AND day = 28
      AND host = 'COLOQUE_O_HOSTNAME'
      AND log LIKE '%COLOQUE_O_TEXTO%'
    ORDER BY ts DESC
    LIMIT 200;
  SQL
}

############################################
# Outputs
############################################
output "athena_workgroup" {
  value = aws_athena_workgroup.logs.name
}

output "glue_database" {
  value = aws_glue_catalog_database.logs.name
}

output "crawler_name" {
  value = aws_glue_crawler.logs.name
}

output "athena_results_bucket" {
  value = "${local.athena_results_bucket}/athena-results/"
}

output "start_crawler_cmd" {
  value = "aws glue start-crawler --name ${aws_glue_crawler.logs.name} --region ${var.region}"
}
