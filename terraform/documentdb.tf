# =============================================================================
# Amazon DocumentDB (MongoDB-compatible) for Execution Service (Phase 4)
# =============================================================================

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "execution" {
  name       = "${var.project_name}-execution-docdb-subnet-${var.environment}"
  subnet_ids = local.db_subnet_ids

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-execution-docdb-subnet-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "execution" {
  family      = "docdb5.0"
  name        = "${var.project_name}-execution-docdb-params-${var.environment}"
  description = "DocumentDB cluster parameter group for Execution Service"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "ttl_monitor"
    value = "enabled"
  }

  parameter {
    name  = "audit_logs"
    value = var.environment == "production" ? "enabled" : "disabled"
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-execution-docdb-params-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

# Random password for DocumentDB
resource "random_password" "documentdb_password" {
  length  = 32
  special = true
  # DocumentDB password requirements
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "execution" {
  cluster_identifier      = "${var.project_name}-execution-${var.environment}"
  engine                  = "docdb"
  engine_version          = "5.0.0"
  master_username         = "docdbadmin"
  master_password         = random_password.documentdb_password.result
  backup_retention_period = var.environment == "production" ? 7 : 1
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-execution-final-${var.environment}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  db_subnet_group_name            = aws_docdb_subnet_group.execution.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.execution.name
  vpc_security_group_ids          = [aws_security_group.documentdb.id]

  # Encryption at rest
  storage_encrypted = true
  kms_key_id        = var.environment == "production" ? aws_kms_key.documentdb[0].arn : null

  # Enable CloudWatch logs
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-execution-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "execution" {
  count = var.environment == "production" ? 2 : 1 # 2 instances for production, 1 for dev

  identifier         = "${var.project_name}-execution-${var.environment}-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.execution.id
  instance_class     = var.environment == "production" ? "db.t3.medium" : "db.t3.medium"

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-execution-${var.environment}-${count.index + 1}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

# Security Group for DocumentDB
resource "aws_security_group" "documentdb" {
  name        = "${var.project_name}-documentdb-sg-${var.environment}"
  description = "Security group for DocumentDB cluster (Execution Service)"
  vpc_id      = data.aws_vpc.selected.id

  # Allow MongoDB traffic from VPC (EKS pods and Lambda functions)
  ingress {
    description = "MongoDB from VPC"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-documentdb-sg-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

# KMS Key for DocumentDB encryption (production only)
resource "aws_kms_key" "documentdb" {
  count = var.environment == "production" ? 1 : 0

  description             = "KMS key for DocumentDB encryption - ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-documentdb-key-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

resource "aws_kms_alias" "documentdb" {
  count = var.environment == "production" ? 1 : 0

  name          = "alias/${var.project_name}-documentdb-${var.environment}"
  target_key_id = aws_kms_key.documentdb[0].key_id
}

# Store DocumentDB credentials in Secrets Manager
resource "aws_secretsmanager_secret" "documentdb_credentials" {
  name        = "${var.project_name}/${var.environment}/documentdb/credentials"
  description = "DocumentDB connection credentials for Execution Service"

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-documentdb-credentials-${var.environment}"
    Service = "execution-service"
    Phase   = "Phase-4"
  })
}

resource "aws_secretsmanager_secret_version" "documentdb_credentials" {
  secret_id = aws_secretsmanager_secret.documentdb_credentials.id

  secret_string = jsonencode({
    username = aws_docdb_cluster.execution.master_username
    password = random_password.documentdb_password.result
    host     = aws_docdb_cluster.execution.endpoint
    port     = aws_docdb_cluster.execution.port
    database = "execution_service_${var.environment}"
    uri      = "mongodb://${aws_docdb_cluster.execution.master_username}:${random_password.documentdb_password.result}@${aws_docdb_cluster.execution.endpoint}:${aws_docdb_cluster.execution.port}/execution_service_${var.environment}?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  })
}

# IAM Policy for execution-service to access DocumentDB credentials
resource "aws_iam_policy" "execution_service_secrets" {
  name        = "${var.project_name}-execution-service-secrets-${var.environment}"
  description = "Allow Execution Service to read DocumentDB credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDocumentDBCredentials"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.documentdb_credentials.arn
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}
