# =============================================================================
# RDS PostgreSQL - Database Managed Infrastructure
# =============================================================================
# Provisiona uma instancia RDS PostgreSQL gerenciada pela AWS
# =============================================================================

# -----------------------------------------------------------------------------
# Geracao de Senha Aleatoria (se nao fornecida)
# -----------------------------------------------------------------------------

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  # Nao regenerar se ja existe
  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

locals {
  # Usa senha fornecida ou gera uma nova
  db_password_final = var.db_password != "" ? var.db_password : random_password.db_password.result
}

# -----------------------------------------------------------------------------
# Subnet Group para o RDS
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Subnet group for RDS PostgreSQL - FIAP Tech Challenge"
  subnet_ids  = local.db_subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Parameter Group para PostgreSQL
# -----------------------------------------------------------------------------

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-pg15-params"
  family      = "postgres15"
  description = "Custom parameter group for PostgreSQL 15 - FIAP Tech Challenge"

  # Configuracoes otimizadas para a aplicacao
  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries acima de 1 segundo
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  parameter {
    name  = "timezone"
    value = "America/Sao_Paulo"
  }

  parameter {
    name  = "client_encoding"
    value = "UTF8"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-pg15-params"
    Environment = var.environment
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Instancia RDS PostgreSQL
# -----------------------------------------------------------------------------

resource "aws_db_instance" "postgres" {
  identifier = local.db_identifier

  # Engine Configuration
  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Storage Configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage > 0 ? var.db_max_allocated_storage : null
  storage_type          = "gp2" # FREE TIER: gp2 is more compatible than gp3
  storage_encrypted     = true

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = local.db_password_final
  port     = var.db_port

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.db_publicly_accessible
  multi_az               = var.db_multi_az

  # Backup Configuration
  backup_retention_period = var.db_backup_retention_period
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window
  copy_tags_to_snapshot   = true

  # Deletion Configuration
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.db_identifier}-final-snapshot"

  # Performance Insights (disponivel no free tier)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Monitoring
  monitoring_interval = 0 # 0 = desabilitado (requer IAM role para habilitar)

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Apply changes immediately (cuidado em producao!)
  apply_immediately = var.environment != "production"

  tags = merge(var.common_tags, {
    Name        = local.db_identifier
    Environment = var.environment
    Component   = "database"
    Engine      = "postgresql"
    Version     = var.db_engine_version
  })

  lifecycle {
    prevent_destroy = false # true em producao

    # Ignorar mudancas na senha (gerenciada pelo Secrets Manager)
    ignore_changes = [password]
  }

  depends_on = [
    aws_db_subnet_group.main,
    aws_db_parameter_group.postgres,
    aws_security_group.rds
  ]
}
