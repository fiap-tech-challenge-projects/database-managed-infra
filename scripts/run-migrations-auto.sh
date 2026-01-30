#!/bin/bash
# =============================================================================
# Automated Migration Trigger
# =============================================================================
# Runs automatically in CI/CD after Terraform creates RDS
# Triggers Kubernetes Job to run migrations
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Automated Database Migration${NC}"
echo -e "${GREEN}========================================${NC}"

ENVIRONMENT="${ENVIRONMENT:-staging}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="fiap-tech-challenge-eks-${ENVIRONMENT}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-118735037876}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  EKS Cluster: $CLUSTER_NAME"

echo -e "\n${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo -e "\n${YELLOW}Ensuring namespace exists...${NC}"
kubectl create namespace "ftc-app-${ENVIRONMENT}" --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Creating Prisma schema ConfigMap...${NC}"
kubectl create configmap prisma-schema-files \
  --from-file=../prisma/schema/ \
  --namespace="ftc-app-${ENVIRONMENT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Cleaning up previous migration job if exists...${NC}"
kubectl delete job database-migration -n "ftc-app-${ENVIRONMENT}" --ignore-not-found=true

echo -e "\n${YELLOW}Creating ServiceAccount for migrations...${NC}"
# Production: ServiceAccount inherits permissions from node IAM role
# Node role has necessary permissions for Secrets Manager and RDS
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
cat ../k8s/migration-job.yaml | \
  sed "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" | \
  sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
  sed '/^---$/,$d' | \
  kubectl apply -f - || {
    echo -e "${RED}Failed to create migration job!${NC}"
    echo -e "${YELLOW}Showing processed YAML:${NC}"
    cat ../k8s/migration-job.yaml | \
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
  echo -e "\n${GREEN}Migration completed successfully!${NC}"
  echo -e "\n${YELLOW}Full migration logs:${NC}"
  cat /tmp/migration-logs.txt 2>/dev/null || kubectl logs job/database-migration -n "ftc-app-${ENVIRONMENT}"
  exit 0
else
  echo -e "\n${RED}Migration failed or timed out!${NC}"
  echo -e "\n${YELLOW}Job status:${NC}"
  kubectl get job database-migration -n "ftc-app-${ENVIRONMENT}" -o yaml 2>/dev/null || echo "Job not found (may have been deleted by ttlSecondsAfterFinished)"
  echo -e "\n${YELLOW}Pod status:${NC}"
  kubectl get pods -n "ftc-app-${ENVIRONMENT}" -l app=database-migration
  echo -e "\n${YELLOW}Pod events:${NC}"
  kubectl get events -n "ftc-app-${ENVIRONMENT}" --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | tail -20
  echo -e "\n${YELLOW}Complete pod logs (captured during execution):${NC}"
  if [ -f /tmp/migration-logs.txt ]; then
    cat /tmp/migration-logs.txt
  else
    kubectl logs -n "ftc-app-${ENVIRONMENT}" -l app=database-migration --all-containers=true --tail=200 || echo "No logs available"
  fi
  exit 1
fi
