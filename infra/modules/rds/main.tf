resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "RDS access - restricted to ECS tasks"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db-sg" })
}

resource "aws_security_group_rule" "db_ingress_from_ecs" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = each.value
  description              = "DB port from allowed SG"
}

resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# FIXME: move this to Secrets Manager when we wire up rotation.
# SSM is fine for now - we just read it once at boot.
resource "random_password" "master" {
  length  = 24
  special = true
  # RDS rejects a handful of these in the master password
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.name}/rds/master_password"
  type  = "SecureString"
  value = random_password.master.result
  tags  = var.tags
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-db"

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result
  port     = var.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  performance_insights_enabled = true
  auto_minor_version_upgrade   = true

  tags = merge(var.tags, { Name = "${var.name}-db" })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}
