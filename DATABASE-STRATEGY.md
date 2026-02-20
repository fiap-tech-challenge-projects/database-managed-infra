# Phase 4 Database Strategy

## Decision: DynamoDB for All NoSQL Needs

**Date:** 2026-02-11  
**Status:** Implemented ✅

## Context

Phase 4 requires:
- Minimum 3 microservices
- Each with its own database
- At least 1 SQL database
- At least 1 NoSQL database
- No direct database access between services

The implementation plan originally suggested:
- PostgreSQL (RDS) for OS Service
- DynamoDB for Billing Service
- **DocumentDB (MongoDB)** for Execution Service

## Problem

DocumentDB is **not available in AWS Free Tier**:
- Error: "FreeTierRestrictionError: The specified cluster engine type is not available with free plan accounts"
- This applies to both AWS Academy and paid free tier accounts
- DocumentDB costs ~$50-70/month for minimum instance (db.t3.medium)

## Decision

**Use DynamoDB for ALL NoSQL needs** instead of DocumentDB.

### Rationale

1. ✅ **Satisfies Phase 4 Requirements:**
   - PostgreSQL (SQL) ✅
   - DynamoDB (NoSQL) ✅
   - Each service has own database ✅

2. ✅ **AWS Free Tier Compatible:**
   - DynamoDB offers 25GB storage free forever
   - Pay-per-request billing (no provisioned capacity)
   - No minimum instance costs

3. ✅ **Saga Pattern Support:**
   - DynamoDB supports complex queries via GSI
   - Conditional writes for distributed locking
   - DynamoDB Streams for event sourcing (if needed)

4. ✅ **Scalability:**
   - Automatic scaling with pay-per-request
   - No manual capacity planning

## Implementation

### Database Architecture

```
OS Service      → PostgreSQL (RDS)    [SQL]
Billing Service → DynamoDB (3 tables) [NoSQL]
Execution Service → DynamoDB (3 tables) [NoSQL]
```

### Billing Service Tables (DynamoDB)

1. **budgets** - Budget tracking with versioning
   - Hash: `budgetId`, Range: `version`
   - GSI: `ServiceOrderIndex`, `StatusIndex`

2. **payments** - Payment records (Mercado Pago)
   - Hash: `paymentId`, Range: `timestamp`
   - GSI: `BudgetIndex`, `ServiceOrderIndex`, `MercadoPagoIndex`

3. **budget_items** - Budget line items
   - Hash: `budgetId`, Range: `itemId`

### Execution Service Tables (DynamoDB)

1. **executions** - Saga workflow instances
   - Hash: `executionId`, Range: `timestamp`
   - GSI: `ServiceOrderIndex`, `StatusIndex`
   - TTL enabled for automatic cleanup

2. **execution_steps** - Individual saga steps
   - Hash: `executionId`, Range: `stepNumber`
   - GSI: `StatusIndex`

3. **work_queue** - Execution queue with priority
   - Hash: `queueId`, Range: `priority`
   - GSI: `ServiceOrderIndex`, `StatusPriorityIndex`
   - TTL enabled

## Alternatives Considered

### 1. MongoDB Atlas
- ❌ Free tier limited to 512MB
- ❌ Additional vendor dependency
- ❌ Network egress costs from AWS

### 2. Self-hosted MongoDB on EKS
- ❌ Complex operational overhead
- ❌ Persistent volume costs
- ❌ Manual backup/recovery
- ❌ No AWS integration

### 3. Enable DocumentDB Later
- ⚠️ Possible for production deployment
- ⚠️ Requires budget for ~$50-70/month
- ⚠️ Migration effort from DynamoDB

## Consequences

### Positive

- ✅ Stays within AWS Free Tier
- ✅ Simplified infrastructure (fewer services)
- ✅ Better AWS integration (IAM, CloudWatch, etc.)
- ✅ No operational overhead
- ✅ Automatic scaling and backups

### Negative

- ⚠️ DynamoDB query patterns less flexible than MongoDB
- ⚠️ Requires careful GSI design
- ⚠️ Migration path if DocumentDB needed later

### Mitigation

- Design data models with DynamoDB best practices
- Use GSIs for all query patterns
- Keep data access layer abstracted for future portability

## Validation

✅ Meets Phase 4 mandatory requirements:
- Minimum 3 microservices: OS, Billing, Execution
- At least 1 SQL database: PostgreSQL ✅
- At least 1 NoSQL database: DynamoDB ✅
- Each service has own database ✅
- No cross-service database access ✅

## References

- [Phase 4 PDF](./12SOAT%20-%20Fase%204%20-%20Tech%20challenge.pdf)
- [Implementation Plan](./tmp-doc/PHASE-4-IMPLEMENTATION-PLAN.md)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
