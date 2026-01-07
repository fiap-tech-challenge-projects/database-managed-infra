# =============================================================================
# Security Groups - Database Managed Infrastructure
# =============================================================================
# Define os security groups para controle de acesso ao RDS PostgreSQL
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group para o RDS
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL - FIAP Tech Challenge"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Component   = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Regras de Ingress (Entrada)
# -----------------------------------------------------------------------------

# Permite acesso de dentro da VPC (EKS pods, Lambda, etc.)
resource "aws_security_group_rule" "rds_ingress_vpc" {
  type              = "ingress"
  from_port         = var.db_port
  to_port           = var.db_port
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.rds.id
  description       = "Allow PostgreSQL access from VPC CIDR"
}

# Permite acesso de CIDR blocks especificos (se configurado)
resource "aws_security_group_rule" "rds_ingress_allowed_cidrs" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.db_port
  to_port           = var.db_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.rds.id
  description       = "Allow PostgreSQL access from allowed CIDR blocks"
}

# Permite acesso de security groups especificos (EKS nodes, Lambda, etc.)
resource "aws_security_group_rule" "rds_ingress_allowed_sgs" {
  count = length(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from security group ${var.allowed_security_groups[count.index]}"
}

# -----------------------------------------------------------------------------
# Regras de Egress (Saida)
# -----------------------------------------------------------------------------

# Permite todo trafego de saida (necessario para health checks e replicacao)
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}

# -----------------------------------------------------------------------------
# Security Group para acesso de Lambda (se necessario)
# -----------------------------------------------------------------------------

resource "aws_security_group" "lambda_rds_access" {
  name        = "${var.project_name}-${var.environment}-lambda-rds-sg"
  description = "Security group for Lambda functions accessing RDS"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-lambda-rds-sg"
    Environment = var.environment
    Component   = "lambda"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Egress para Lambda acessar o RDS
resource "aws_security_group_rule" "lambda_egress_rds" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.lambda_rds_access.id
  description              = "Allow Lambda to connect to RDS"
}

# Egress para Lambda acessar a internet (HTTPS para AWS APIs)
resource "aws_security_group_rule" "lambda_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_rds_access.id
  description       = "Allow Lambda HTTPS outbound for AWS APIs"
}

# Ingress no RDS permitindo acesso do Lambda SG
resource "aws_security_group_rule" "rds_ingress_lambda" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_rds_access.id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from Lambda functions"
}
