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

echo -e "\n${YELLOW}Creating Prisma schema ConfigMap...${NC}"
kubectl create configmap prisma-schema-files \
  --from-file=../prisma/schema/ \
  --namespace="ftc-app-${ENVIRONMENT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Applying migration job...${NC}"
cat ../k8s/migration-job.yaml | \
  sed "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" | \
  sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
  kubectl apply -f -

echo -e "\n${YELLOW}Waiting for migration job to complete...${NC}"
kubectl wait --for=condition=complete --timeout=300s \
  job/database-migration \
  -n "ftc-app-${ENVIRONMENT}" || true

JOB_STATUS=$(kubectl get job database-migration -n "ftc-app-${ENVIRONMENT}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')

if [ "$JOB_STATUS" == "True" ]; then
  echo -e "\n${GREEN}Migration completed successfully!${NC}"
  kubectl logs job/database-migration -n "ftc-app-${ENVIRONMENT}"
  exit 0
else
  echo -e "\n${RED}Migration failed!${NC}"
  kubectl logs job/database-migration -n "ftc-app-${ENVIRONMENT}"
  exit 1
fi
