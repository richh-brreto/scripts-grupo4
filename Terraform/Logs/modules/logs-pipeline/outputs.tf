output "glue_database"   { value = aws_glue_catalog_database.logs.name }
output "glue_crawler"    { value = aws_glue_crawler.bronze.name }
output "glue_job"        { value = aws_glue_job.bronze_to_silver.name }
output "glue_workflow"   { value = aws_glue_workflow.logs.name }
output "athena_workgroup" { value = aws_athena_workgroup.logs.name }
