output "alb_dns" {
  value = module.ecs.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "db_password_ssm_param" {
  value = module.rds.password_ssm_param
}
