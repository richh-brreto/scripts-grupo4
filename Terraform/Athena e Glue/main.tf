terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  bucket_arn = "arn:aws:s3:::${var.bronze_bucket}"
}

############################
# Instancias ja existentes (criadas por outro Terraform)
# Localiza pelos IPs privados e coloca a tag usada pelo SSM
############################
data "aws_instances" "alvo" {
  filter {
    name   = "private-ip-address"
    values = var.instance_ips
  }
  instance_state_names = ["running"]
}

resource "aws_ec2_tag" "fluentbit" {
  for_each    = toset(data.aws_instances.alvo.ids)
  resource_id = each.value
  key         = var.fluentbit_tag_key
  value       = var.fluentbit_tag_value
}

############################
# IAM - Learner Lab: IAM bloqueado, usa a LabRole ja existente
# (ela ja tem acesso a S3, Glue, Athena e SSM)
############################
data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

############################
# Glue
############################
resource "aws_glue_catalog_database" "logs" {
  name = var.glue_database
}

resource "aws_glue_crawler" "logs" {
  name          = "logs-bronze-${var.environment}"
  database_name = aws_glue_catalog_database.logs.name
  role          = data.aws_iam_role.lab.arn
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.bronze_bucket}/logs/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

############################
# Athena
############################
# Bucket de resultados do Athena: criado fora do Terraform (CLI), porque a SCP
# do Learner Lab bloqueia s3:GetBucketObjectLockConfiguration, lido pelo provider.
# aws s3 mb s3://infra-lab-athena-results-dev --region us-east-1

resource "aws_athena_workgroup" "logs" {
  name = "logs-${var.environment}"

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/results/"
    }
  }
}

############################
# Fluent Bit via SSM (instancias com a tag)
############################
resource "aws_ssm_document" "fluentbit" {
  name            = "install-fluentbit-${var.environment}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Instala e configura o Fluent Bit"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "install"
      inputs = {
        runCommand = [
          "if ! command -v fluent-bit >/dev/null 2>&1 && [ ! -x /opt/fluent-bit/bin/fluent-bit ]; then curl -s https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh; fi",
          "mkdir -p /var/lib/fluent-bit/s3 /etc/fluent-bit",
          "cat > /etc/fluent-bit/fluent-bit.conf <<'FBEOF'",
          templatefile("${path.module}/fluent-bit.conf.tpl", {
            bucket   = var.bronze_bucket
            region   = var.region
            log_path = var.log_path
          }),
          "FBEOF",
          "systemctl enable fluent-bit",
          "systemctl restart fluent-bit"
        ]
      }
    }]
  })
}

resource "aws_ssm_association" "fluentbit" {
  name                = aws_ssm_document.fluentbit.name
  schedule_expression = "rate(30 minutes)"

  targets {
    key    = "tag:${var.fluentbit_tag_key}"
    values = [var.fluentbit_tag_value]
  }

  depends_on = [aws_ec2_tag.fluentbit]
}

############################
# Outputs
############################
output "instancias_marcadas" {
  value = data.aws_instances.alvo.ids
}

output "glue_database" {
  value = aws_glue_catalog_database.logs.name
}

output "glue_crawler" {
  value = aws_glue_crawler.logs.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.logs.name
}
