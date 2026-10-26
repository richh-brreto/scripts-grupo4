# =====================================================================
#  Pipeline de análise da base externa (ANAC)
#
#  bronze (partes CSV da Lambda) -> job Glue -> silver (agregado mensal)
#  -> tabela no Glue Data Catalog -> Athena (workgroup, views e consultas)
#
#  A tabela é declarada aqui em vez de criada por crawler: o esquema do
#  agregado é fixo (6 colunas), então não há custo de crawler nem risco
#  de o crawler inferir tipo errado no CSV com separador ";".
# =====================================================================

data "aws_iam_role" "glue" {
  name = var.glue_role_name
}

locals {
  prefixo      = lower(var.project_name)
  script_key   = "_glue/scripts/anac_bronze_para_silver.py"
  tabela_voos  = "voos_brasil_paises_ingleses"
  sql_views    = fileset(var.athena_sql_dir, "views/*.sql")
  sql_consulta = fileset(var.athena_sql_dir, "consultas/*.sql")
}

# ---------------------------------------------------------------------
# Job bronze -> silver
# ---------------------------------------------------------------------
resource "aws_s3_object" "glue_script" {
  bucket      = var.silver_bucket
  key         = local.script_key
  source      = var.glue_script_path
  source_hash = filemd5(var.glue_script_path) # etag não serve com SSE-KMS (gera diff a cada plan)
}

resource "aws_glue_job" "anac_bronze_to_silver" {
  name              = "${local.prefixo}-anac-bronze-to-silver"
  description       = "Filtra os voos Brasil -> EUA, Canadá e Reino Unido e grava o agregado mensal no silver"
  role_arn          = data.aws_iam_role.glue.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 20

  command {
    name            = "glueetl"
    script_location = "s3://${var.silver_bucket}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"  = "python"
    "--BRONZE_BUCKET" = var.bronze_bucket
    "--SILVER_BUCKET" = var.silver_bucket
    "--TempDir"       = "s3://${var.silver_bucket}/_glue/tmp/"
  }
}

# ---------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------
resource "aws_glue_catalog_database" "analise" {
  name        = var.database_name
  description = "Base externa da ANAC tratada para a análise de sazonalidade da demanda"
}

resource "aws_glue_catalog_table" "voos" {
  database_name = aws_glue_catalog_database.analise.name
  name          = local.tabela_voos
  description   = "Agregado mensal de voos comerciais de passageiros do Brasil para EUA, Canadá e Reino Unido"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification           = "csv"
    "skip.header.line.count" = "1"
    EXTERNAL                 = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${var.silver_bucket}/${local.tabela_voos}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = ";"
        "serialization.format" = ";"
      }
    }

    columns {
      name    = "ano"
      type    = "int"
      comment = "Ano da partida real"
    }
    columns {
      name    = "mes"
      type    = "int"
      comment = "Mês da partida real (1 a 12)"
    }
    columns {
      name    = "estacao"
      type    = "string"
      comment = "Estação do ano no hemisfério sul"
    }
    columns {
      name    = "temporada"
      type    = "string"
      comment = "férias escolares, volta às aulas ou período letivo"
    }
    columns {
      name    = "qtd_voos"
      type    = "int"
      comment = "Voos comerciais com passageiros pagos ou grátis"
    }
    columns {
      name    = "nr_passageiros"
      type    = "bigint"
      comment = "Passageiros pagos + grátis"
    }
  }
}

# ---------------------------------------------------------------------
# Athena
# ---------------------------------------------------------------------
resource "aws_athena_workgroup" "analise" {
  name          = "${local.prefixo}-analise"
  description   = "Consultas da análise de sazonalidade (base ANAC)"
  force_destroy = true # permite destroy mesmo com histórico de consultas

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false
    bytes_scanned_cutoff_per_query     = 1073741824 # 1 GB

    result_configuration {
      output_location = "s3://${var.gold_bucket}/_athena-results/analise/"
    }
  }
}

resource "aws_athena_named_query" "views" {
  for_each    = local.sql_views
  name        = "analise - view - ${trimsuffix(basename(each.value), ".sql")}"
  description = "Executar uma vez antes das consultas: cria a view"
  workgroup   = aws_athena_workgroup.analise.id
  database    = aws_glue_catalog_database.analise.name
  query       = file("${var.athena_sql_dir}/${each.value}")
}

resource "aws_athena_named_query" "consultas" {
  for_each  = local.sql_consulta
  name      = "analise - ${trimsuffix(basename(each.value), ".sql")}"
  workgroup = aws_athena_workgroup.analise.id
  database  = aws_glue_catalog_database.analise.name
  query     = file("${var.athena_sql_dir}/${each.value}")
}
