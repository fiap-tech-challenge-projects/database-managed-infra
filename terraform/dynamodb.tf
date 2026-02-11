# =============================================================================
# DynamoDB Tables for Billing Service (Phase 4)
# =============================================================================

# Table: Budgets
resource "aws_dynamodb_table" "budgets" {
  name           = "${var.project_name}-budgets-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST" # On-demand pricing (no capacity planning needed)
  hash_key       = "budgetId"
  range_key      = "version"

  attribute {
    name = "budgetId"
    type = "S" # String
  }

  attribute {
    name = "version"
    type = "N" # Number (for budget revisions)
  }

  attribute {
    name = "serviceOrderId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI for querying budgets by service order
  global_secondary_index {
    name            = "ServiceOrderIndex"
    hash_key        = "serviceOrderId"
    projection_type = "ALL"
  }

  # GSI for querying budgets by status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "budgetId"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old budgets (optional)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.environment == "production" ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-budgets-${var.environment}"
    Service     = "billing-service"
    Phase       = "Phase-4"
    DataType    = "Budget"
  })
}

# Table: Payments
resource "aws_dynamodb_table" "payments" {
  name         = "${var.project_name}-payments-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "paymentId"
  range_key    = "timestamp"

  attribute {
    name = "paymentId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S" # ISO 8601 timestamp
  }

  attribute {
    name = "budgetId"
    type = "S"
  }

  attribute {
    name = "serviceOrderId"
    type = "S"
  }

  attribute {
    name = "mercadoPagoId"
    type = "S"
  }

  # GSI for querying payments by budget
  global_secondary_index {
    name            = "BudgetIndex"
    hash_key        = "budgetId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # GSI for querying payments by service order
  global_secondary_index {
    name            = "ServiceOrderIndex"
    hash_key        = "serviceOrderId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # GSI for querying by Mercado Pago ID (for webhook lookups)
  global_secondary_index {
    name            = "MercadoPagoIndex"
    hash_key        = "mercadoPagoId"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old completed payments (90 days)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.environment == "production" ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-payments-${var.environment}"
    Service     = "billing-service"
    Phase       = "Phase-4"
    DataType    = "Payment"
  })
}

# Table: BudgetItems
resource "aws_dynamodb_table" "budget_items" {
  name         = "${var.project_name}-budget-items-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "budgetId"
  range_key    = "itemId"

  attribute {
    name = "budgetId"
    type = "S"
  }

  attribute {
    name = "itemId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.environment == "production" ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-budget-items-${var.environment}"
    Service     = "billing-service"
    Phase       = "Phase-4"
    DataType    = "BudgetItem"
  })
}

# KMS Key for DynamoDB encryption (production only)
resource "aws_kms_key" "dynamodb" {
  count = var.environment == "production" ? 1 : 0

  description             = "KMS key for DynamoDB table encryption - ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-dynamodb-key-${var.environment}"
    Service = "billing-service"
    Phase   = "Phase-4"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count = var.environment == "production" ? 1 : 0

  name          = "alias/${var.project_name}-dynamodb-${var.environment}"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

# IAM Policy for billing-service to access DynamoDB tables
resource "aws_iam_policy" "billing_service_dynamodb" {
  name        = "${var.project_name}-billing-service-dynamodb-${var.environment}"
  description = "Allow Billing Service to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "DynamoDBTableAccess"
          Effect = "Allow"
          Action = [
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:ConditionCheckItem",
            "dynamodb:PutItem",
            "dynamodb:DescribeTable",
            "dynamodb:DeleteItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem"
          ]
          Resource = [
            aws_dynamodb_table.budgets.arn,
            "${aws_dynamodb_table.budgets.arn}/index/*",
            aws_dynamodb_table.payments.arn,
            "${aws_dynamodb_table.payments.arn}/index/*",
            aws_dynamodb_table.budget_items.arn
          ]
        }
      ],
      var.environment == "production" ? [
        {
          Sid    = "DynamoDBKMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [aws_kms_key.dynamodb[0].arn]
        }
      ] : []
    )
  })

  tags = var.common_tags
}
