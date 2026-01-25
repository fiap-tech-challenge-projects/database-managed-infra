# =============================================================================
# FIAP Tech Challenge - Database Managed Infrastructure
# =============================================================================
# Este modulo provisiona a infraestrutura de banco de dados gerenciado na AWS
# utilizando RDS PostgreSQL com alta disponibilidade e seguranca.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }

  # Backend S3 - bucket configured dynamically via terraform init -backend-config
  backend "s3" {
    key            = "database-managed-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fiap-terraform-locks"
  }
}

# Provider AWS
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Data source para obter informacoes da conta AWS
data "aws_caller_identity" "current" {}

# Data source para obter a VPC do EKS (sera criada pelo kubernetes-core-infra)
# Se a VPC nao existir ainda, usa a VPC default
data "aws_vpc" "selected" {
  id = var.vpc_id != "" ? var.vpc_id : null

  dynamic "filter" {
    for_each = var.vpc_id == "" ? [1] : []
    content {
      name   = "tag:Environment"
      values = [var.environment]
    }
  }

  dynamic "filter" {
    for_each = var.vpc_id == "" ? [1] : []
    content {
      name   = "tag:Name"
      values = ["${var.project_name}-vpc-${var.environment}"]
    }
  }

  default = var.vpc_id == "" ? true : false
}

# Data source para obter subnets privadas
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Tier = "private"
  }
}

# Fallback: se nao encontrar subnets com tag, usa todas as subnets da VPC
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

locals {
  # Usa subnets privadas se disponiveis, senao usa todas
  db_subnet_ids = length(data.aws_subnets.private.ids) > 0 ? data.aws_subnets.private.ids : data.aws_subnets.all.ids

  # Nome do banco de dados
  db_name = "fiap_db"

  # Identificador do RDS
  db_identifier = "${var.project_name}-${var.environment}-postgres"
}
