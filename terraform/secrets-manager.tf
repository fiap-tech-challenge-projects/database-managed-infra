# =============================================================================
# AWS Secrets Manager - Database Managed Infrastructure
# =============================================================================
# Armazena credenciais sensiveis de forma segura no AWS Secrets Manager
# =============================================================================

# -----------------------------------------------------------------------------
# Geracao de JWT Secret (se nao fornecido)
# -----------------------------------------------------------------------------

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # JWT secrets geralmente sao alphanumericos

  lifecycle {
    ignore_changes = [length, special]
  }
}

locals {
  # Usa JWT secret fornecido ou gera um novo
  jwt_secret_final = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret.result

  # Connection string para a aplicacao
  database_url = "postgresql://${var.db_username}:${urlencode(local.db_password_final)}@${aws_db_instance.postgres.endpoint}/${var.db_name}"

  # Connection string sem senha (para logs)
  database_url_safe = "postgresql://${var.db_username}:***@${aws_db_instance.postgres.endpoint}/${var.db_name}"
}

# -----------------------------------------------------------------------------
# Secret para Credenciais do Banco de Dados
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "database_credentials" {
  name        = "${var.project_name}/${var.environment}/database/credentials"
  description = "Database credentials for FIAP Tech Challenge - ${var.environment}"

  recovery_window_in_days = var.secrets_recovery_window

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-db-credentials"
    Environment = var.environment
    Component   = "secrets"
    Type        = "database"
  })
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id

  secret_string = jsonencode({
    username             = var.db_username
    password             = local.db_password_final
    engine               = "postgres"
    host                 = aws_db_instance.postgres.address
    port                 = var.db_port
    dbname               = var.db_name
    dbInstanceIdentifier = aws_db_instance.postgres.identifier

    # Connection strings para diferentes ORMs/drivers
    DATABASE_URL = local.database_url
    JDBC_URL     = "jdbc:postgresql://${aws_db_instance.postgres.address}:${var.db_port}/${var.db_name}"
  })

  lifecycle {
    # Ignorar mudancas para nao recriar o secret a cada apply
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------------------------------------
# Secret para Configuracoes de Autenticacao (JWT)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "auth_config" {
  name        = "${var.project_name}/${var.environment}/auth/config"
  description = "Authentication configuration for FIAP Tech Challenge - ${var.environment}"

  recovery_window_in_days = var.secrets_recovery_window

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-auth-config"
    Environment = var.environment
    Component   = "secrets"
    Type        = "authentication"
  })
}

resource "aws_secretsmanager_secret_version" "auth_config" {
  secret_id = aws_secretsmanager_secret.auth_config.id

  secret_string = jsonencode({
    JWT_SECRET             = local.jwt_secret_final
    JWT_EXPIRES_IN         = var.jwt_expires_in
    JWT_REFRESH_EXPIRES_IN = var.jwt_refresh_expires_in
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------------------------------------
# Secret com todas as variaveis de ambiente da aplicacao
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app_env" {
  name        = "${var.project_name}/${var.environment}/app/env"
  description = "Application environment variables for FIAP Tech Challenge - ${var.environment}"

  recovery_window_in_days = var.secrets_recovery_window

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-app-env"
    Environment = var.environment
    Component   = "secrets"
    Type        = "application"
  })
}

resource "aws_secretsmanager_secret_version" "app_env" {
  secret_id = aws_secretsmanager_secret.app_env.id

  secret_string = jsonencode({
    # Database
    DATABASE_URL      = local.database_url
    POSTGRES_HOST     = aws_db_instance.postgres.address
    POSTGRES_PORT     = tostring(var.db_port)
    POSTGRES_DB       = var.db_name
    POSTGRES_USER     = var.db_username
    POSTGRES_PASSWORD = local.db_password_final

    # JWT
    JWT_SECRET             = local.jwt_secret_final
    JWT_EXPIRES_IN         = var.jwt_expires_in
    JWT_REFRESH_EXPIRES_IN = var.jwt_refresh_expires_in

    # Environment
    NODE_ENV    = var.environment == "production" ? "production" : "development"
    ENVIRONMENT = var.environment
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy para acesso aos secrets (para EKS e Lambda)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "AllowSecretsAccess"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.database_credentials.arn,
      aws_secretsmanager_secret.auth_config.arn,
      aws_secretsmanager_secret.app_env.arn
    ]
  }

  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-${var.environment}-secrets-access"
  description = "Policy to allow access to Secrets Manager secrets for FIAP Tech Challenge"
  policy      = data.aws_iam_policy_document.secrets_access.json

  # AWS Academy: Cannot tag IAM policies (iam:TagPolicy not allowed)
  # tags = merge(var.common_tags, {
  #   Name        = "${var.project_name}-${var.environment}-secrets-access"
  #   Environment = var.environment
  # })
}
