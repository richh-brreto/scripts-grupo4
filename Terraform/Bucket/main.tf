module "medallion_storage" {
  source            = "../modules/Buckets"
  project_name      = var.project_name
  environment       = var.environment
  aws_access_key    = var.aws_access_key
  aws_secret_key    = var.aws_secret_key
  aws_session_token = var.aws_session_token
}

output "buckets" { value = module.medallion_storage.buckets }
