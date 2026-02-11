# =============================================================================
# Variaveis de Entrada - Database Managed Infrastructure
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Regiao AWS para deploy dos recursos"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.aws_region))
    error_message = "AWS region deve seguir o formato: us-east-1, eu-west-1, etc."
  }
}

variable "vpc_id" {
  description = "ID da VPC onde o RDS sera criado. Se vazio, busca VPC com tag Name=fiap-eks-vpc"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Nome do projeto (usado para nomear recursos)"
  type        = string
  default     = "fiap-tech-challenge"

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.project_name))
    error_message = "Project name deve ser lowercase com letras, numeros e hifens."
  }
}

variable "environment" {
  description = "Ambiente de deploy (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment deve ser: development, staging ou production."
  }
}

variable "enable_documentdb" {
  description = "Enable DocumentDB (MongoDB-compatible). Set to false for AWS Academy (not supported in free tier)"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags comuns aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project   = "fiap-tech-challenge"
    Phase     = "3"
    ManagedBy = "terraform"
    Team      = "fiap-pos-grad"
  }
}

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------

variable "db_instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro" # Free tier eligible

  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "Instance class deve comecar com 'db.' (ex: db.t3.micro)."
  }
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado em GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 1000
    error_message = "Allocated storage deve ser entre 20 e 1000 GB."
  }
}

variable "db_max_allocated_storage" {
  description = "Armazenamento maximo para auto-scaling em GB (0 = desabilitado)"
  type        = number
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= 0 && var.db_max_allocated_storage <= 1000
    error_message = "Max allocated storage deve ser entre 0 e 1000 GB."
  }
}

variable "db_engine_version" {
  description = "Versao do PostgreSQL"
  type        = string
  default     = "15" # Will use latest minor version (15.10 as of Jan 2026)
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "fiap_db"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name deve comecar com letra e conter apenas letras, numeros e underscore."
  }
}

variable "db_username" {
  description = "Usuario master do banco de dados"
  type        = string
  default     = "fiap_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "Username deve comecar com letra e conter apenas letras, numeros e underscore."
  }
}

variable "db_password" {
  description = "Senha do usuario master (se vazio, sera gerada automaticamente)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port > 0 && var.db_port <= 65535
    error_message = "Port deve ser entre 1 e 65535."
  }
}

variable "db_multi_az" {
  description = "Habilitar Multi-AZ para alta disponibilidade"
  type        = bool
  default     = false # false para economizar no AWS Academy
}

variable "db_publicly_accessible" {
  description = "Tornar o RDS acessivel publicamente (NAO RECOMENDADO para producao)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Habilitar protecao contra exclusao acidental"
  type        = bool
  default     = false # false para facilitar teardown no AWS Academy
}

variable "db_skip_final_snapshot" {
  description = "Pular snapshot final ao destruir o RDS"
  type        = bool
  default     = true # true para facilitar teardown no AWS Academy
}

variable "db_backup_retention_period" {
  description = "Dias de retencao de backups automaticos (0 = desabilitado)"
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "Backup retention deve ser entre 0 e 35 dias."
  }
}

variable "db_backup_window" {
  description = "Janela de backup preferencial (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Janela de manutencao preferencial (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitidos para acesso ao RDS (alem da VPC)"
  type        = list(string)
  default     = []
}

variable "allowed_security_groups" {
  description = "Security groups IDs permitidos para acesso ao RDS"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Secrets Manager Configuration
# -----------------------------------------------------------------------------

variable "secrets_recovery_window" {
  description = "Dias de espera antes de deletar um secret (0 = imediato)"
  type        = number
  default     = 0 # 0 para facilitar teardown no AWS Academy

  validation {
    condition     = var.secrets_recovery_window >= 0 && var.secrets_recovery_window <= 30
    error_message = "Recovery window deve ser entre 0 e 30 dias."
  }
}

# -----------------------------------------------------------------------------
# JWT Configuration
# -----------------------------------------------------------------------------

variable "jwt_secret" {
  description = "Secret para assinatura JWT (se vazio, sera gerado automaticamente)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_expires_in" {
  description = "Tempo de expiracao do JWT"
  type        = string
  default     = "24h"
}

variable "jwt_refresh_expires_in" {
  description = "Tempo de expiracao do refresh token"
  type        = string
  default     = "7d"
}
