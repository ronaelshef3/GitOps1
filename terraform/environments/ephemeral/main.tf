#
module "quakewatch_infra" {
  source = "../../modules/k3s_cluster"

  # הגדרות ספציפיות לסביבה הזמנית
  instance_type = "t3.small"
  env_name      = "ephemeral"
  aws_region    = var.aws_region
}

#
output "server_ip" {
  value = module.quakewatch_infra.public_ip
}