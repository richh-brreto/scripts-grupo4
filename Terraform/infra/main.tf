module "Infrastructure" {
  source       = "../modules/infra"
  project_name = var.project_name
  environment  = var.environment
}
