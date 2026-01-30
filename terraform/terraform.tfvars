# =============================================================================
# Terraform Variables - Database Managed Infrastructure
# =============================================================================
# Valores padrao para o ambiente de desenvolvimento (AWS Academy)
# =============================================================================

# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "fiap-tech-challenge"
environment  = "development"

common_tags = {
  Project   = "fiap-tech-challenge"
  Phase     = "3"
  ManagedBy = "terraform"
  Team      = "fiap-pos-grad"
}

# RDS Configuration
db_instance_class        = "db.t3.micro" # Free tier eligible
db_allocated_storage     = 20
db_max_allocated_storage = 100
db_engine_version        = "15" # Latest PostgreSQL 15.x (AWS Academy compatible)
db_name                  = "fiap_db"
db_username              = "fiap_admin"
db_port                  = 5432

# High Availability (desabilitado para AWS Academy)
db_multi_az            = false
db_publicly_accessible = false

# Protection (desabilitado para facilitar teardown no AWS Academy)
db_deletion_protection = false
db_skip_final_snapshot = true

# Backup Configuration - FREE TIER COMPATIBLE
db_backup_retention_period = 0 # FREE TIER: Backup automático não suportado
db_backup_window           = "03:00-04:00"
db_maintenance_window      = "Mon:04:00-Mon:05:00"

# Secrets Manager
secrets_recovery_window = 0 # 0 para deletar imediatamente (AWS Academy)

# JWT Configuration
jwt_expires_in         = "24h"
jwt_refresh_expires_in = "7d"
