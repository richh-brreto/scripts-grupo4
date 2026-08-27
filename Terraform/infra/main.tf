module "Infrastructure" {
  source             = "../modules/infra"
  project_name       = var.project_name
  environment        = var.environment
  aws_access_key     = var.aws_access_key
  aws_secret_key     = var.aws_secret_key
  aws_session_token  = var.aws_session_token
}
