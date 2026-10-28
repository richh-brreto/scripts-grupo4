output "glue_job" {
  value = aws_glue_job.anac_bronze_to_silver.name
}

output "database" {
  value = aws_glue_catalog_database.analise.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.analise.name
}

output "consultas_salvas" {
  value = sort(concat(
    [for q in aws_athena_named_query.views : q.name],
    [for q in aws_athena_named_query.consultas : q.name],
  ))
}

output "lambda_ingestao_url" {
  description = "URL para enviar as partes: POST <url>?filename=combinadaYYYY-MM/<parte>.csv"
  value       = aws_lambda_function_url.ingestao.function_url
}
