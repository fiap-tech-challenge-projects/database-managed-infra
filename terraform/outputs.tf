# =============================================================================
# Outputs - Database Managed Infrastructure
# =============================================================================
# Exporta informacoes importantes para uso por outros modulos
# =============================================================================

# -----------------------------------------------------------------------------
# RDS Instance Outputs
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "Endpoint de conexao do RDS (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "Hostname do RDS (sem porta)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.postgres.port
}

output "rds_identifier" {
  description = "Identificador da instancia RDS"
  value       = aws_db_instance.postgres.identifier
}

output "rds_arn" {
  description = "ARN da instancia RDS"
  value       = aws_db_instance.postgres.arn
}

output "rds_resource_id" {
  description = "Resource ID da instancia RDS"
  value       = aws_db_instance.postgres.resource_id
}

output "rds_availability_zone" {
  description = "Availability Zone onde o RDS esta rodando"
  value       = aws_db_instance.postgres.availability_zone
}

# -----------------------------------------------------------------------------
# Database Configuration Outputs
# -----------------------------------------------------------------------------

output "database_name" {
  description = "Nome do banco de dados"
  value       = var.db_name
}

output "database_username" {
  description = "Usuario do banco de dados"
  value       = var.db_username
}

output "database_url_safe" {
  description = "Connection string do banco (sem senha, para logs)"
  value       = local.database_url_safe
}

# -----------------------------------------------------------------------------
# Security Groups Outputs
# -----------------------------------------------------------------------------

output "rds_security_group_id" {
  description = "ID do Security Group do RDS"
  value       = aws_security_group.rds.id
}

output "rds_security_group_arn" {
  description = "ARN do Security Group do RDS"
  value       = aws_security_group.rds.arn
}

output "lambda_rds_security_group_id" {
  description = "ID do Security Group para Lambda acessar RDS"
  value       = aws_security_group.lambda_rds_access.id
}

output "lambda_rds_security_group_arn" {
  description = "ARN do Security Group para Lambda acessar RDS"
  value       = aws_security_group.lambda_rds_access.arn
}

# -----------------------------------------------------------------------------
# Secrets Manager Outputs
# -----------------------------------------------------------------------------

output "database_credentials_secret_arn" {
  description = "ARN do secret com credenciais do banco"
  value       = aws_secretsmanager_secret.database_credentials.arn
}

output "database_credentials_secret_name" {
  description = "Nome do secret com credenciais do banco"
  value       = aws_secretsmanager_secret.database_credentials.name
}

output "auth_config_secret_arn" {
  description = "ARN do secret com configuracoes de autenticacao"
  value       = aws_secretsmanager_secret.auth_config.arn
}

output "auth_config_secret_name" {
  description = "Nome do secret com configuracoes de autenticacao"
  value       = aws_secretsmanager_secret.auth_config.name
}

output "app_env_secret_arn" {
  description = "ARN do secret com variaveis de ambiente da aplicacao"
  value       = aws_secretsmanager_secret.app_env.arn
}

output "app_env_secret_name" {
  description = "Nome do secret com variaveis de ambiente da aplicacao"
  value       = aws_secretsmanager_secret.app_env.name
}

# -----------------------------------------------------------------------------
# IAM Policy Outputs
# -----------------------------------------------------------------------------

output "secrets_access_policy_arn" {
  description = "ARN da IAM policy para acesso aos secrets"
  value       = aws_iam_policy.secrets_access.arn
}

output "secrets_access_policy_name" {
  description = "Nome da IAM policy para acesso aos secrets"
  value       = aws_iam_policy.secrets_access.name
}

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID da VPC onde o RDS esta localizado"
  value       = data.aws_vpc.selected.id
}

output "db_subnet_group_name" {
  description = "Nome do subnet group do RDS"
  value       = aws_db_subnet_group.main.name
}

output "db_subnet_ids" {
  description = "IDs das subnets do RDS"
  value       = local.db_subnet_ids
}

# -----------------------------------------------------------------------------
# Parameter Group Outputs
# -----------------------------------------------------------------------------

output "db_parameter_group_name" {
  description = "Nome do parameter group do RDS"
  value       = aws_db_parameter_group.postgres.name
}

output "db_parameter_group_arn" {
  description = "ARN do parameter group do RDS"
  value       = aws_db_parameter_group.postgres.arn
}

# -----------------------------------------------------------------------------
# Summary Output (para facilitar integracao)
# -----------------------------------------------------------------------------

output "summary" {
  description = "Resumo das informacoes importantes para integracao"
  value = {
    rds = {
      endpoint   = aws_db_instance.postgres.endpoint
      address    = aws_db_instance.postgres.address
      port       = aws_db_instance.postgres.port
      identifier = aws_db_instance.postgres.identifier
      database   = var.db_name
      username   = var.db_username
    }
    security_groups = {
      rds_sg    = aws_security_group.rds.id
      lambda_sg = aws_security_group.lambda_rds_access.id
    }
    secrets = {
      database_credentials = aws_secretsmanager_secret.database_credentials.name
      auth_config          = aws_secretsmanager_secret.auth_config.name
      app_env              = aws_secretsmanager_secret.app_env.name
    }
    iam = {
      secrets_policy_arn = aws_iam_policy.secrets_access.arn
    }
  }
}
