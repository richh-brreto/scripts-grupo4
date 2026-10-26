# Pipeline de análise da base ANAC (Glue + Athena)

Sobe o job `glue_bronze_para_silver.py` no Glue, cataloga o agregado do silver e cria o workgroup do Athena com as consultas de `../code/Athena/`.

Arquivos usados (caminhos relativos a esta pasta):

| O quê | Onde |
|---|---|
| Job do Glue | `../code/Glue/glue_bronze_para_silver.py` (cópia sem alterações de `scripts/` do `analise-dados-grupo4`) |
| View | `../code/Athena/views/` |
| Consultas | `../code/Athena/consultas/` |

| Recurso | Nome |
|---|---|
| Glue Job | `boost-anac-bronze-to-silver` (Glue 4.0, 2 workers G.1X, timeout 20 min) |
| Glue Database | `boost_analise` |
| Tabela | `voos_brasil_paises_ingleses` (CSV `;`, UTF-8, cabeçalho ignorado) em `s3://<silver>/voos_brasil_paises_ingleses/` |
| Athena Workgroup | `boost-analise`, resultados em `s3://<gold>/_athena-results/analise/`, limite de 1 GB por consulta |
| Consultas salvas | `analise - view - ...` e `analise - 01...` até `06...` |

O job usa a `LabRole`, porque o AWS Academy não permite criar roles. Nada aqui altera configuração dos buckets (lifecycle, criptografia): só grava o script em `_glue/scripts/`.

## Como executar

Pré-requisitos: Terraform e AWS CLI instalados, lab iniciado e as partes da ANAC já no bucket bronze, em `combinadaYYYY-MM/` (geradas pelo `scripts/chunk_arquivos.py` do `analise-dados-grupo4` e enviadas pela Lambda).

```bash
# credenciais do Learner Lab (AWS Details > AWS CLI em ~/.aws/credentials)
_c(){ grep -m1 "^$1" ~/.aws/credentials | cut -d= -f2- | tr -d ' \r'; }
export TF_VAR_aws_access_key="$(_c aws_access_key_id)"
export TF_VAR_aws_secret_key="$(_c aws_secret_access_key)"
export TF_VAR_aws_session_token="$(_c aws_session_token)"

cd Terraform/ANAC/analise-anac
cp terraform.tfvars.example terraform.tfvars   # preencher os 3 buckets
terraform init && terraform apply

# gera o agregado no silver (rodar de novo quando chegarem meses novos da ANAC)
aws glue start-job-run --job-name boost-anac-bronze-to-silver
```

Athena: Query editor > Workgroup `boost-analise` > Database `boost_analise` > Saved queries. Execute primeiro `analise - view - 01_vw_voos_mensal` e depois as consultas.

## Consultas

| Consulta | Responde |
|---|---|
| `01_sazonalidade_por_mes` | índice sazonal: passageiros do mês contra a média (100 = mês típico) |
| `02_demanda_por_temporada` | férias escolares x volta às aulas x período letivo |
| `03_demanda_por_estacao` | demanda por estação do ano |
| `04_variacao_ano_contra_ano` | mesmo mês, ano contra ano |
| `05_ranking_meses` | 10 meses com mais passageiros |
| `06_conferencia_ingestao` | o que está na tabela e o que a view descartou |

A view `vw_voos_mensal` descarta meses residuais (menos de 10% da média de voos). Hoje isso tira agosto/2026, que só tem 2 voos: partiram em agosto, mas vieram no arquivo de julho da ANAC. A coluna `competencia` (data do 1º dia do mês) é a chave para cruzar com as datas de início dos contratos.

Para remover tudo: `terraform destroy` (os dados no S3 ficam).
