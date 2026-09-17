region      = "ap-south-1"
environment = "dev"
name_prefix = "booking-dev"

container_image = "public.ecr.aws/nginx/nginx:1.27"
desired_count   = 1
task_cpu        = 256
task_memory     = 512

db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_backup_retention_days = 3
db_deletion_protection   = false
db_multi_az              = false
