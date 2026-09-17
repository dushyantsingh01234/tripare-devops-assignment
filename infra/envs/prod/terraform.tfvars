region      = "ap-south-1"
environment = "prod"
name_prefix = "booking-prod"

container_image = "public.ecr.aws/nginx/nginx:1.27"
desired_count   = 3
task_cpu        = 1024
task_memory     = 2048

db_instance_class        = "db.m6g.large"
db_allocated_storage     = 100
db_backup_retention_days = 30
db_deletion_protection   = true
db_multi_az              = true
