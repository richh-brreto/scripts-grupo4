module "medallion_storage" {
  source       = "../modules/medallion"
  project_name = var.project_name
  environment  = var.environment
}
