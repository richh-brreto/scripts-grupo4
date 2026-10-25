# =====================================================================
#  Pipeline dedicado aos logs: bronze (JSON) -> Glue -> silver (Parquet) -> Athena
#
#  Workflow "<project>-logs-pipeline":
#    gatilho agendado -> crawler bronze (cataloga JSON + partições)
#                     -> job bronze->silver (bookmark, Parquet, atualiza catálogo)
#  Athena: workgroup próprio, consultas salvas e views
# =====================================================================

data "aws_iam_role" "glue" {
  name = var.glue_role_name
}

locals {
  prefixo     = lower(var.project_name)
  bronze_logs = "s3://${var.bronze_bucket}/logs"
  silver_logs = "s3://${var.silver_bucket}/logs"
  sql_views   = fileset(var.athena_sql_dir, "views/*.sql")
  sql_queries = fileset(var.athena_sql_dir, "consultas/*.sql")
}

# ---------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------
resource "aws_glue_catalog_database" "logs" {
  name        = var.database_name
  description = "Logs da aplicação Boost Your English: bronze_* (JSON bruto) e silver_* (Parquet tratado)"
}

# ---------------------------------------------------------------------
# Crawler do bronze: uma tabela por fonte, partições vindas das pastas
# ---------------------------------------------------------------------
resource "aws_glue_crawler" "bronze" {
  name          = "${local.prefixo}-logs-bronze-crawler"
  database_name = aws_glue_catalog_database.logs.name
  role          = data.aws_iam_role.glue.arn
  table_prefix  = "bronze_"
  description   = "Cataloga os logs brutos gravados pelo Fluent Bit no bucket bronze"

  s3_target { path = "${local.bronze_logs}/containers/" }
  s3_target { path = "${local.bronze_logs}/nginx/" }
  s3_target { path = "${local.bronze_logs}/sistema/" }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  configuration = jsonencode({
    Version  = 1.0
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

# ---------------------------------------------------------------------
# Job bronze -> silver
# ---------------------------------------------------------------------
resource "aws_s3_object" "glue_script" {
  bucket = var.silver_bucket
  key    = "_glue/scripts/logs_bronze_to_silver.py"
  source      = var.glue_script_path
  source_hash = filemd5(var.glue_script_path) # etag não serve com SSE-KMS (geraria diff em todo plan)
}

resource "aws_glue_job" "bronze_to_silver" {
  name              = "${local.prefixo}-logs-bronze-to-silver"
  role_arn          = data.aws_iam_role.glue.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 20
  max_retries       = 0
  description       = "Trata os logs do bronze e grava Parquet particionado no silver"

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.silver_bucket}/${aws_s3_object.glue_script.key}"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.silver_bucket}/_glue/tmp/"
    "--DATABASE"                         = aws_glue_catalog_database.logs.name
    "--SILVER_PATH"                      = local.silver_logs
  }
}

# ---------------------------------------------------------------------
# Orquestração: workflow + gatilhos
# ---------------------------------------------------------------------
resource "aws_glue_workflow" "logs" {
  name        = "${local.prefixo}-logs-pipeline"
  description = "Crawler do bronze seguido do job bronze->silver dos logs"
}

resource "aws_glue_trigger" "inicio" {
  name          = "${local.prefixo}-logs-inicio"
  workflow_name = aws_glue_workflow.logs.name
  type          = "SCHEDULED"
  schedule      = var.agendamento
  enabled       = var.agendamento_ativo

  actions {
    crawler_name = aws_glue_crawler.bronze.name
  }
}

resource "aws_glue_trigger" "apos_crawler" {
  name          = "${local.prefixo}-logs-apos-crawler"
  workflow_name = aws_glue_workflow.logs.name
  type          = "CONDITIONAL"

  predicate {
    conditions {
      crawler_name = aws_glue_crawler.bronze.name
      crawl_state  = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.bronze_to_silver.name
  }
}

# ---------------------------------------------------------------------
# Athena
# ---------------------------------------------------------------------
resource "aws_athena_workgroup" "logs" {
  name          = "${local.prefixo}-logs"
  description   = "Consultas sobre os logs (bronze e silver)"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 1073741824 # 1 GB por consulta

    result_configuration {
      output_location = "s3://${var.gold_bucket}/_athena-results/logs/"
    }
  }
}

resource "aws_athena_named_query" "views" {
  for_each    = local.sql_views
  name        = "logs - view - ${trimsuffix(basename(each.value), ".sql")}"
  workgroup   = aws_athena_workgroup.logs.id
  database    = aws_glue_catalog_database.logs.name
  query       = file("${var.athena_sql_dir}/${each.value}")
  description = "Executar uma vez após o primeiro job (cria a view)"
}

resource "aws_athena_named_query" "consultas" {
  for_each  = local.sql_queries
  name      = "logs - ${trimsuffix(basename(each.value), ".sql")}"
  workgroup = aws_athena_workgroup.logs.id
  database  = aws_glue_catalog_database.logs.name
  query     = file("${var.athena_sql_dir}/${each.value}")
}

# ---------------------------------------------------------------------
# Retenção dos logs brutos no bronze (versionamento está ligado no bucket)
# ---------------------------------------------------------------------
# Atenção: este recurso SUBSTITUI todas as regras de lifecycle do bucket.
# Se o bronze já tem regras próprias, use gerenciar_retencao_bronze = false.
resource "aws_s3_bucket_lifecycle_configuration" "bronze_logs" {
  count  = var.gerenciar_retencao_bronze ? 1 : 0
  bucket = var.bronze_bucket

  rule {
    id     = "logs-brutos"
    status = "Enabled"
    filter { prefix = "logs/" }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.retencao_bronze_dias
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
