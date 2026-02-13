# Database Managed Infrastructure

Infraestrutura de banco de dados gerenciado para o FIAP Tech Challenge - Fase 3.

## Visao Geral

Este repositorio contem a infraestrutura como codigo (IaC) para provisionar e gerenciar o banco de dados PostgreSQL na AWS utilizando RDS (Relational Database Service).

### Arquitetura

```
                    +-------------------+
                    |   AWS Cloud       |
                    |                   |
    +---------------+-------------------+---------------+
    |               |                   |               |
    |   +-------+   |   +-----------+   |   +-------+   |
    |   | EKS   |   |   |    RDS    |   |   | Lambda|   |
    |   | Pods  |---+-->| PostgreSQL|<--+---| Funcs |   |
    |   +-------+   |   +-----------+   |   +-------+   |
    |               |         |         |               |
    +---------------+---------+---------+---------------+
                              |
                    +---------+---------+
                    |  Secrets Manager  |
                    |  - DB Credentials |
                    |  - JWT Secret     |
                    +-------------------+
```

## Recursos Provisionados

- **RDS PostgreSQL 15**: Instancia de banco de dados gerenciada
- **Security Groups**: Controle de acesso ao banco
- **Subnet Group**: Subnets para o RDS
- **Parameter Group**: Configuracoes otimizadas do PostgreSQL
- **Secrets Manager**: Armazenamento seguro de credenciais
- **IAM Policy**: Permissoes para acesso aos secrets

## Tecnologias

| Tecnologia | Versao | Descricao |
|------------|--------|-----------|
| Terraform | >= 1.5 | Infrastructure as Code |
| AWS RDS | PostgreSQL 15 | Banco de dados gerenciado |
| AWS Secrets Manager | - | Gerenciamento de credenciais |
| Prisma | 6.x | ORM e migrations |

## Pre-requisitos

1. **AWS CLI** configurada com credenciais validas
2. **Terraform** >= 1.5.0 instalado
3. **Node.js** >= 20.x para rodar migrations
4. **Bucket S3** para Terraform state (ver [Configuracao do Backend](#configuracao-do-backend))

## Configuracao do Backend

Antes do primeiro `terraform init`, crie o bucket S3 e tabela DynamoDB para o state:

```bash
# Criar bucket S3
aws s3 mb s3://fiap-tech-challenge-tf-state-118735037876 --region us-east-1

# Habilitar versionamento
aws s3api put-bucket-versioning \
  --bucket fiap-tech-challenge-tf-state-118735037876 \
  --versioning-configuration Status=Enabled

# Criar tabela DynamoDB para locking
aws dynamodb create-table \
  --table-name fiap-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Deploy

### 1. Inicializar Terraform

```bash
cd terraform
terraform init
```

### 2. Revisar o plano

```bash
terraform plan
```

### 3. Aplicar a infraestrutura

```bash
terraform apply
```

### 4. Executar migrations

Apos o RDS estar disponivel:

```bash
# Instalar dependencias
npm install

# Executar script de migracao
chmod +x scripts/run-migrations.sh
./scripts/run-migrations.sh
```

## Variaveis de Configuracao

| Variavel | Descricao | Default |
|----------|-----------|---------|
| `aws_region` | Regiao AWS | `us-east-1` |
| `environment` | Ambiente (development/production) | `development` |
| `db_instance_class` | Classe da instancia RDS | `db.t3.micro` |
| `db_allocated_storage` | Armazenamento em GB | `20` |
| `db_engine_version` | Versao do PostgreSQL | `15.4` |
| `db_multi_az` | Alta disponibilidade | `false` |

Ver `terraform/variables.tf` para lista completa.

## Outputs

Apos o deploy, os seguintes outputs estarao disponiveis:

```bash
# Endpoint do RDS
terraform output rds_endpoint

# ARN do secret com credenciais
terraform output database_credentials_secret_arn

# Security Group do RDS
terraform output rds_security_group_id

# Resumo completo
terraform output summary
```

## Estrutura de Diretorios

```
database-managed-infra/
├── terraform/
│   ├── main.tf                 # Provider e backend
│   ├── variables.tf            # Variaveis de entrada
│   ├── rds.tf                  # Instancia RDS
│   ├── security-groups.tf      # Security Groups
│   ├── secrets-manager.tf      # Secrets Manager
│   ├── outputs.tf              # Outputs
│   └── terraform.tfvars        # Valores das variaveis
├── prisma/
│   └── schema/                 # Schema do banco de dados
│       ├── schema.prisma       # Configuracao principal
│       ├── auth.prisma         # Tabelas de autenticacao
│       ├── clients.prisma      # Tabelas de clientes
│       ├── service-orders.prisma # Tabelas de OS
│       └── ...
├── scripts/
│   └── run-migrations.sh       # Script de migracao
├── .github/
│   └── workflows/
│       └── terraform.yml       # CI/CD
└── README.md
```

## CI/CD

O pipeline do GitHub Actions executa:

1. **fmt**: Verifica formatacao do Terraform
2. **validate**: Valida a sintaxe
3. **plan**: Gera plano de execucao (comentario no PR)
4. **apply**: Aplica mudancas (apenas na branch main)

### Secrets necessarios no GitHub

- `AWS_ACCESS_KEY_ID`: Access Key da AWS
- `AWS_SECRET_ACCESS_KEY`: Secret Key da AWS

## Seguranca

- Credenciais armazenadas no AWS Secrets Manager
- Security Groups restritivos (apenas VPC interna)
- Criptografia em repouso habilitada
- Performance Insights para monitoramento

## Troubleshooting

### Erro de conexao com o RDS

```bash
# Verificar security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Verificar se o RDS esta disponivel
aws rds describe-db-instances --db-instance-identifier fiap-tech-challenge-development-postgres
```

### Erro ao obter secrets

```bash
# Verificar se o secret existe
aws secretsmanager list-secrets --region us-east-1

# Obter valor do secret
aws secretsmanager get-secret-value --secret-id fiap-tech-challenge/development/database/credentials
```

## Cleanup

Para destruir toda a infraestrutura:

```bash
cd terraform
terraform destroy
```

**ATENCAO**: Isso ira deletar o banco de dados e todos os dados!

## Links Relacionados

- [FIAP Tech Challenge - Plano Fase 3](../PHASE-3-PLAN.md)
- [Projeto Principal - k8s-main-service](../k8s-main-service)
- [Lambda Authorizer](../lambda-api-handler)
- [Kubernetes Infrastructure](../kubernetes-core-infra)

## Equipe

- Ana Shurman
- Franklin Campos
- Rafael Lima (Finha)
- Bruna Euzane

---

**FIAP Pos-Graduacao em Arquitetura de Software - Tech Challenge Fase 3**
