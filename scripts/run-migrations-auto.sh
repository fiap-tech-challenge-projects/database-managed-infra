#!/bin/bash
# =============================================================================
# Automated Migration Trigger
# =============================================================================
# Runs automatically in CI/CD after Terraform creates RDS
# Builds Docker image with migrations and triggers Kubernetes Job
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Automated Database Migration${NC}"
echo -e "${GREEN}========================================${NC}"

ENVIRONMENT="${ENVIRONMENT:-development}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="fiap-tech-challenge-eks-${ENVIRONMENT}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-118735037876}"
echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  EKS Cluster: $CLUSTER_NAME"

# Docker image is already built and pushed to ECR by GitHub Actions workflow
# ECR authentication is automatic via EKS node IAM role - no imagePullSecrets needed
LATEST_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/database-migrations:${ENVIRONMENT}"

echo -e "\n${YELLOW}Using Docker image from ECR:${NC}"
echo "  ${LATEST_IMAGE}"
echo -e "${GREEN}(Image was built and pushed by GitHub Actions workflow)${NC}"

echo -e "\n${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo -e "\n${YELLOW}Ensuring namespace exists...${NC}"
kubectl create namespace "ftc-app-${ENVIRONMENT}" --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Cleaning up previous migration job if exists...${NC}"
kubectl delete job database-migration -n "ftc-app-${ENVIRONMENT}" --ignore-not-found=true

echo -e "\n${YELLOW}Creating ServiceAccount for migrations...${NC}"
# ServiceAccount inherits permissions from EKS node IAM role
# Node role has permissions for:
# - ECR image pulling (automatic, no imagePullSecrets needed)
# - Secrets Manager (read database credentials)
# - RDS (connect to database)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: migration-service-account
  namespace: ftc-app-${ENVIRONMENT}
  # AWS ACADEMY: Uncomment the annotation below to use LabRole
  # annotations:
  #   eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/LabRole
EOF

echo -e "\n${YELLOW}Applying migration job...${NC}"

# Script is executed from scripts/ directory by GitHub Actions
# So we need to go up one level to access k8s/ directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATION_JOB_YAML="$REPO_ROOT/k8s/migration-job.yaml"

if [ ! -f "$MIGRATION_JOB_YAML" ]; then
  echo -e "${RED}Error: migration-job.yaml not found at $MIGRATION_JOB_YAML${NC}"
  exit 1
fi

cat "$MIGRATION_JOB_YAML" | \
  sed "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" | \
  sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
  sed '/^---$/,$d' | \
  kubectl apply -f - || {
    echo -e "${RED}Failed to create migration job!${NC}"
    echo -e "${YELLOW}Showing processed YAML:${NC}"
    cat "$MIGRATION_JOB_YAML" | \
      sed "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" | \
      sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
      sed '/^---$/,$d'
    exit 1
  }

echo -e "\n${YELLOW}Verifying job was created...${NC}"
kubectl get job database-migration -n "ftc-app-${ENVIRONMENT}" || {
  echo -e "${RED}Job was not created! Checking namespace resources:${NC}"
  kubectl get all -n "ftc-app-${ENVIRONMENT}"
  exit 1
}

echo -e "\n${YELLOW}Checking pod status...${NC}"
sleep 5
kubectl get pods -n "ftc-app-${ENVIRONMENT}" -l app=database-migration

echo -e "\n${YELLOW}Streaming pod logs (will follow until completion)...${NC}"
# Stream logs in background and save to file
kubectl logs -f -n "ftc-app-${ENVIRONMENT}" -l app=database-migration --all-containers=true 2>&1 | tee /tmp/migration-logs.txt &
LOGS_PID=$!

echo -e "\n${YELLOW}Waiting for migration job to complete (timeout: 10 minutes)...${NC}"
kubectl wait --for=condition=complete --timeout=600s \
  job/database-migration \
  -n "ftc-app-${ENVIRONMENT}" || true

# Stop log streaming
kill $LOGS_PID 2>/dev/null || true

JOB_STATUS=$(kubectl get job database-migration -n "ftc-app-${ENVIRONMENT}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')

if [ "$JOB_STATUS" == "True" ]; then
  echo -e "\n${GREEN}✅ Migration completed successfully!${NC}"
  echo -e "\n${YELLOW}Full migration logs:${NC}"
  cat /tmp/migration-logs.txt 2>/dev/null || kubectl logs job/database-migration -n "ftc-app-${ENVIRONMENT}"
  exit 0
else
  echo -e "\n${RED}❌ Migration failed or timed out!${NC}"
  echo -e "\n${YELLOW}Job status:${NC}"
  kubectl get job database-migration -n "ftc-app-${ENVIRONMENT}" -o yaml 2>/dev/null || echo "Job not found"
  echo -e "\n${YELLOW}Pod status:${NC}"
  kubectl get pods -n "ftc-app-${ENVIRONMENT}" -l app=database-migration
  echo -e "\n${YELLOW}Complete pod logs:${NC}"
  if [ -f /tmp/migration-logs.txt ]; then
    cat /tmp/migration-logs.txt
  else
    kubectl logs -n "ftc-app-${ENVIRONMENT}" -l app=database-migration --all-containers=true --tail=200 || echo "No logs available"
  fi
  exit 1
fi
