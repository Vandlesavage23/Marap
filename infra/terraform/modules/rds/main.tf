resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db" })
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name_prefix}-pg16-"
  family      = "postgres16"
  description = "${var.name_prefix} PostgreSQL 16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = tostring(var.log_min_duration_statement_ms)
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = "mc"
  username = "mc_admin"
  port     = 5432

  # The master password is generated and rotated by RDS into Secrets Manager; it never appears in
  # Terraform configuration or variables (it is not stored in state either).
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period   = var.pitr_retention_days
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = !var.deletion_protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name_prefix}-postgres-final" : null

  auto_minor_version_upgrade            = true
  apply_immediately                     = var.apply_immediately
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres" })
}

# ---------------------------------------------------------------- AWS Backup (daily, 35 days in prod)
resource "aws_backup_vault" "this" {
  count       = var.enable_aws_backup ? 1 : 0
  name        = "${var.name_prefix}-rds"
  kms_key_arn = var.kms_key_arn
  tags        = var.tags
}

resource "aws_backup_plan" "this" {
  count = var.enable_aws_backup ? 1 : 0
  name  = "${var.name_prefix}-rds-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this[0].name
    schedule          = "cron(30 0 * * ? *)"
    lifecycle {
      delete_after = var.snapshot_retention_days
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  count              = var.enable_aws_backup ? 1 : 0
  name               = "${var.name_prefix}-rds-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = var.enable_aws_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "this" {
  count        = var.enable_aws_backup ? 1 : 0
  name         = "${var.name_prefix}-rds"
  iam_role_arn = aws_iam_role.backup[0].arn
  plan_id      = aws_backup_plan.this[0].id
  resources    = [aws_db_instance.this.arn]
}

data "aws_iam_policy_document" "backup_kms" {
  count = var.enable_aws_backup ? 1 : 0

  statement {
    sid       = "UseBackupKey"
    actions   = ["kms:CreateGrant", "kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "backup_kms" {
  count  = var.enable_aws_backup ? 1 : 0
  name   = "use-backup-kms-key"
  role   = aws_iam_role.backup[0].id
  policy = data.aws_iam_policy_document.backup_kms[0].json
}
