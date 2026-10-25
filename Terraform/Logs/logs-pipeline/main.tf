module "logs_pipeline" {
  source            = "../modules/logs-pipeline"
  project_name      = var.project_name
  bronze_bucket     = var.bronze_bucket
  silver_bucket     = var.silver_bucket
  gold_bucket       = var.gold_bucket
  agendamento_ativo = var.agendamento_ativo
  gerenciar_retencao_bronze = var.gerenciar_retencao_bronze
  glue_script_path  = "${path.root}/../code/Glue/logs_bronze_to_silver.py"
  athena_sql_dir    = "${path.root}/../code/Athena"
  aws_access_key    = var.aws_access_key
  aws_secret_key    = var.aws_secret_key
  aws_session_token = var.aws_session_token
}

output "pipeline" {
  value = {
    database  = module.logs_pipeline.glue_database
    crawler   = module.logs_pipeline.glue_crawler
    job       = module.logs_pipeline.glue_job
    workflow  = module.logs_pipeline.glue_workflow
    workgroup = module.logs_pipeline.athena_workgroup
  }
}
