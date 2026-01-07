#!/bin/bash
# =============================================================================
# Script de Migracao do Banco de Dados
# =============================================================================
# Este script executa as migracoes Prisma no RDS PostgreSQL
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  FIAP Tech Challenge - Database Migration${NC}"
echo -e "${GREEN}========================================${NC}"

# -----------------------------------------------------------------------------
# Verificar pre-requisitos
# -----------------------------------------------------------------------------

echo -e "\n${YELLOW}Verificando pre-requisitos...${NC}"

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Erro: AWS CLI nao encontrado. Instale com: brew install awscli${NC}"
    exit 1
fi

# Verificar jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Erro: jq nao encontrado. Instale com: brew install jq${NC}"
    exit 1
fi

# Verificar npm/npx
if ! command -v npx &> /dev/null; then
    echo -e "${RED}Erro: npx nao encontrado. Instale Node.js${NC}"
    exit 1
fi

echo -e "${GREEN}Todos os pre-requisitos atendidos!${NC}"

# -----------------------------------------------------------------------------
# Configuracao
# -----------------------------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-fiap-tech-challenge/development/database/credentials}"

echo -e "\n${YELLOW}Configuracao:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  Secret Name: $SECRET_NAME"

# -----------------------------------------------------------------------------
# Obter credenciais do Secrets Manager
# -----------------------------------------------------------------------------

echo -e "\n${YELLOW}Obtendo credenciais do Secrets Manager...${NC}"

SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null)

if [ -z "$SECRET_VALUE" ]; then
    echo -e "${RED}Erro: Nao foi possivel obter o secret. Verifique:${NC}"
    echo "  1. Se as credenciais AWS estao configuradas"
    echo "  2. Se o secret existe: $SECRET_NAME"
    echo "  3. Se voce tem permissao para acessar o secret"
    exit 1
fi

# Extrair DATABASE_URL do secret
DATABASE_URL=$(echo "$SECRET_VALUE" | jq -r '.DATABASE_URL')

if [ -z "$DATABASE_URL" ] || [ "$DATABASE_URL" == "null" ]; then
    echo -e "${RED}Erro: DATABASE_URL nao encontrada no secret${NC}"
    exit 1
fi

echo -e "${GREEN}Credenciais obtidas com sucesso!${NC}"

# -----------------------------------------------------------------------------
# Exportar DATABASE_URL
# -----------------------------------------------------------------------------

export DATABASE_URL

# Mostrar URL sem a senha (para debug)
SAFE_URL=$(echo "$DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/***:***@/')
echo -e "\n${YELLOW}Database URL (sanitizada):${NC} $SAFE_URL"

# -----------------------------------------------------------------------------
# Executar migracoes
# -----------------------------------------------------------------------------

echo -e "\n${YELLOW}Executando migracoes Prisma...${NC}"

# Ir para o diretorio do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Gerar cliente Prisma
echo -e "\n${YELLOW}Gerando cliente Prisma...${NC}"
npx prisma generate

# Verificar status das migracoes
echo -e "\n${YELLOW}Verificando status das migracoes...${NC}"
npx prisma migrate status || true

# Executar migracoes
echo -e "\n${YELLOW}Aplicando migracoes...${NC}"
npx prisma migrate deploy

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Migracoes executadas com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"

# -----------------------------------------------------------------------------
# Opcional: Seed de dados iniciais
# -----------------------------------------------------------------------------

if [ "$RUN_SEED" == "true" ]; then
    echo -e "\n${YELLOW}Executando seed de dados...${NC}"
    npx prisma db seed
    echo -e "${GREEN}Seed executado com sucesso!${NC}"
fi
