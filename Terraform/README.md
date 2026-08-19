# Terraform (infra) + Ansible (configuração)

Dois passos, dois comandos, dois momentos:

1. **Terraform** cria a infra (VPC, subnets, gateways, security groups, EFS,
   instâncias, ALB). Nenhuma configuração roda no boot.
2. **Ansible** configura as instâncias (monta o EFS). Você dispara quando
   quiser, quantas vezes quiser — é idempotente, como o terraform apply.

## 1. Criar a infra

```bash
terraform init
terraform apply
```

## 2. Configurar as instâncias

```bash
cd ansible
./generate-inventory.sh      # monta o inventory.ini com os IPs do terraform output
ansible-playbook playbook.yml
```

Isso instala o `nfs-common` e monta o EFS em `/mnt/efs` no bastion, nas 4
instâncias de app e no DB, via SSH através do bastion (`ProxyJump`).

Pré-requisitos: Ansible instalado na sua máquina e a chave SSH (`key_name`)
disponível localmente/no ssh-agent.

## Arquivos

**Infra (Terraform)**
- `providers.tf`, `variables.tf` — configuração base
- `network.tf` — VPC + subnets
- `gateway.tf` — IGW + NAT + route tables
- `security.tf` — security groups
- `storage.tf` — EFS + mount targets
- `compute.tf` — bastion, 4 EC2 de app, EC2 de DB (sem user_data)
- `loadbalancer.tf` — ALB + target group + listener
- `outputs.tf` — DNS do ALB, IP do bastion, DNS do EFS, IPs privados

**Configuração (Ansible)**
- `ansible/generate-inventory.sh` — gera o inventory a partir do `terraform output`
- `ansible/inventory.ini` — gerado automaticamente (não versionar IPs sensíveis se for público)
- `ansible/playbook.yml` — instala nfs-common e monta o EFS
- `ansible/ansible.cfg` — configuração do Ansible

## Por que separar assim

- Terraform: cria/destrói recursos AWS. Não deve saber nada de "o que rodar dentro da máquina".
- Ansible: configura o que já existe, de forma declarativa e repetível — só isso.
- Você decide quando cada um roda; nada é acionado automaticamente pelo outro.
