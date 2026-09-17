module "network" {
  source = "../../modules/network"

  name            = var.name_prefix
  cidr_block      = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

module "ecs" {
  source = "../../modules/ecs"

  name               = var.name_prefix
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  container_image = var.container_image
  desired_count   = var.desired_count
  cpu             = var.task_cpu
  memory          = var.task_memory
}

module "rds" {
  source = "../../modules/rds"

  name       = var.name_prefix
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  allowed_security_group_ids = [module.ecs.task_security_group_id]

  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  multi_az              = var.db_multi_az
  skip_final_snapshot   = true
}
