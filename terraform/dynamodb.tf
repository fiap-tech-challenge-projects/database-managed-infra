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

# =============================================================================
# DynamoDB Tables for Execution Service (Phase 4)
# =============================================================================

# Table: Executions (Saga workflow instances)
resource "aws_dynamodb_table" "executions" {
  name         = "${var.project_name}-executions-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "executionId"
  range_key    = "timestamp"

  attribute {
    name = "executionId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S" # ISO 8601 timestamp
  }

  attribute {
    name = "serviceOrderId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S" # PENDING, IN_PROGRESS, COMPLETED, FAILED, COMPENSATING, COMPENSATED
  }

  # GSI for querying executions by service order
  global_secondary_index {
    name            = "ServiceOrderIndex"
    hash_key        = "serviceOrderId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # GSI for querying executions by status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old completed executions (90 days)
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
    Name     = "${var.project_name}-executions-${var.environment}"
    Service  = "execution-service"
    Phase    = "Phase-4"
    DataType = "Execution"
  })
}

# Table: ExecutionSteps (Individual saga steps)
resource "aws_dynamodb_table" "execution_steps" {
  name         = "${var.project_name}-execution-steps-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "executionId"
  range_key    = "stepNumber"

  attribute {
    name = "executionId"
    type = "S"
  }

  attribute {
    name = "stepNumber"
    type = "N" # Order of execution
  }

  attribute {
    name = "status"
    type = "S" # PENDING, RUNNING, COMPLETED, FAILED, COMPENSATED
  }

  # GSI for querying steps by status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "executionId"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.environment == "production" ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-execution-steps-${var.environment}"
    Service  = "execution-service"
    Phase    = "Phase-4"
    DataType = "ExecutionStep"
  })
}

# Table: WorkQueue (Execution queue management)
resource "aws_dynamodb_table" "work_queue" {
  name         = "${var.project_name}-work-queue-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "queueId"
  range_key    = "priority"

  attribute {
    name = "queueId"
    type = "S"
  }

  attribute {
    name = "priority"
    type = "N" # Higher number = higher priority
  }

  attribute {
    name = "serviceOrderId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S" # QUEUED, ASSIGNED, IN_PROGRESS, COMPLETED
  }

  # GSI for querying by service order
  global_secondary_index {
    name            = "ServiceOrderIndex"
    hash_key        = "serviceOrderId"
    projection_type = "ALL"
  }

  # GSI for querying by status and priority
  global_secondary_index {
    name            = "StatusPriorityIndex"
    hash_key        = "status"
    range_key       = "priority"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old completed work items
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
    Name     = "${var.project_name}-work-queue-${var.environment}"
    Service  = "execution-service"
    Phase    = "Phase-4"
    DataType = "WorkQueue"
  })
}

# IAM Policy for execution-service to access DynamoDB tables
resource "aws_iam_policy" "execution_service_dynamodb" {
  name        = "${var.project_name}-execution-service-dynamodb-${var.environment}"
  description = "Allow Execution Service to access DynamoDB tables"

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
            aws_dynamodb_table.executions.arn,
            "${aws_dynamodb_table.executions.arn}/index/*",
            aws_dynamodb_table.execution_steps.arn,
            "${aws_dynamodb_table.execution_steps.arn}/index/*",
            aws_dynamodb_table.work_queue.arn,
            "${aws_dynamodb_table.work_queue.arn}/index/*"
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
