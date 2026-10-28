# Fluent Bit -> S3 -> Glue -> Athena

1. terraform init && terraform apply
2. Anexe o instance profile (output) nas instancias e coloque a tag fluentbit=true
   (se ja usa role manual, anexe so a policy fluentbit-s3-write nela)
3. Rode o crawler: aws glue start-crawler --name logs-bronze-dev
4. Athena (workgroup logs-dev): SELECT * FROM logs_bronze_dev.logs LIMIT 10;
