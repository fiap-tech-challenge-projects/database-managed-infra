#!/bin/bash
# =============================================================================
# Database Debug Script
# =============================================================================
# Runs a Kubernetes job to check actual database state
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Database Debug Check${NC}"
echo -e "${GREEN}========================================${NC}"

ENVIRONMENT="${ENVIRONMENT:-development}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="fiap-tech-challenge-eks-${ENVIRONMENT}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-118735037876}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  EKS Cluster: $CLUSTER_NAME"

LATEST_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/database-migrations:${ENVIRONMENT}"

echo -e "\n${YELLOW}Using Docker image from ECR:${NC}"
echo "  ${LATEST_IMAGE}"

echo -e "\n${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo -e "\n${YELLOW}Ensuring namespace exists...${NC}"
kubectl create namespace "ftc-app-${ENVIRONMENT}" --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Cleaning up previous debug job if exists...${NC}"
kubectl delete job debug-database -n "ftc-app-${ENVIRONMENT}" --ignore-not-found=true

# Wait a bit for cleanup
sleep 2

echo -e "\n${YELLOW}Applying debug job...${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEBUG_JOB_YAML="$REPO_ROOT/k8s/debug-db-job.yaml"

if [ ! -f "$DEBUG_JOB_YAML" ]; then
  echo -e "${RED}Error: debug-db-job.yaml not found at $DEBUG_JOB_YAML${NC}"
  exit 1
fi

cat "$DEBUG_JOB_YAML" | \
  sed "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" | \
  sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
  kubectl apply -f - || {
    echo -e "${RED}Failed to create debug job!${NC}"
    exit 1
  }

echo -e "\n${YELLOW}Verifying job was created...${NC}"
kubectl get job debug-database -n "ftc-app-${ENVIRONMENT}" || {
  echo -e "${RED}Job was not created!${NC}"
  exit 1
}

echo -e "\n${YELLOW}Waiting for pod to start...${NC}"
sleep 5

echo -e "\n${YELLOW}Pod status:${NC}"
kubectl get pods -n "ftc-app-${ENVIRONMENT}" -l app=debug-database

echo -e "\n${YELLOW}Streaming pod logs...${NC}"
echo ""

# Stream logs and wait for completion
kubectl logs -f -n "ftc-app-${ENVIRONMENT}" -l app=debug-database --all-containers=true 2>&1 &
LOGS_PID=$!

echo -e "\n${YELLOW}Waiting for debug job to complete (timeout: 5 minutes)...${NC}"
kubectl wait --for=condition=complete --timeout=300s \
  job/debug-database \
  -n "ftc-app-${ENVIRONMENT}" || true

# Stop log streaming
kill $LOGS_PID 2>/dev/null || true

JOB_STATUS=$(kubectl get job debug-database -n "ftc-app-${ENVIRONMENT}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')

echo ""
if [ "$JOB_STATUS" == "True" ]; then
  echo -e "${GREEN}✅ Debug check completed successfully!${NC}"
  echo ""
  echo -e "${YELLOW}Full debug output above shows:${NC}"
  echo "  1. What's in the Docker image"
  echo "  2. Database connection status"
  echo "  3. List of all tables"
  echo "  4. Prisma migration history"
  echo "  5. Comparison of files vs database"
  echo "  6. Verification of expected tables"
  exit 0
else
  echo -e "${RED}❌ Debug check failed!${NC}"
  echo -e "\n${YELLOW}Pod logs:${NC}"
  kubectl logs -n "ftc-app-${ENVIRONMENT}" -l app=debug-database --all-containers=true --tail=100 || echo "No logs available"
  exit 1
fi
