# Terraform

Cada configuração raiz abaixo é independente, com state próprio. Os comandos rodam dentro da pasta dela:

```bash
terraform init
terraform plan
terraform apply
```

| Configuração raiz | Módulo | O que cria |
|---|---|---|
| `Bucket/` | `modules/Buckets` | Buckets da arquitetura medalhão (bronze, silver, gold) com versionamento e SSE-KMS |
| `infra/` | `modules/infra` | VPC, EC2 (bastion, front, back, db), ALB, EFS e IAM |
| `Logs/logs-pipeline/` | `Logs/modules/logs-pipeline` | Glue (crawler, job, workflow) e Athena dos logs da aplicação |
| `ANAC/analise-anac/` | nenhum | Job do Glue, tabela no catálogo e Athena da base externa da ANAC. Detalhes em `ANAC/analise-anac/README.md` |

Os pipelines guardam o código que o Terraform publica em `code/`, ao lado da configuração:

```
Logs/code/Glue/       job bronze -> silver dos logs
Logs/code/Athena/     views/ e consultas/ dos logs
Logs/code/FluentBit/  coleta dos logs nas instâncias (envia para o bronze)
ANAC/code/Glue/       job bronze -> silver da ANAC
ANAC/code/Athena/     views/ e consultas/ da ANAC
```

Os dois pipelines usam os buckets `bronze-layer-data-<conta>-us-east-1`, `silver-...` e `gold-...`, informados no `terraform.tfvars` de cada um.

## Credenciais

`Logs/logs-pipeline/` e `ANAC/analise-anac/` têm um `terraform.tfvars.example`: copie para `terraform.tfvars`, que é ignorado pelo git. `Bucket/` e `infra/` só pedem as credenciais (o resto tem valor padrão em `variables.tf`). As credenciais do Learner Lab podem ir no `terraform.tfvars` ou nas variáveis de ambiente `TF_VAR_aws_access_key`, `TF_VAR_aws_secret_key` e `TF_VAR_aws_session_token`. O token expira junto com a sessão do lab.

Nunca commitar `terraform.tfvars`, `*.tfstate` ou a pasta `.terraform/` (já estão no `.gitignore`).
