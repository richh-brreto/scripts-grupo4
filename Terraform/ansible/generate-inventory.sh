#!/bin/bash
# Gera o inventory.ini a partir dos outputs do Terraform.
# Rode depois do "terraform apply".
set -e

cd "$(dirname "$0")/.."   # volta pra pasta do terraform

BASTION_IP=$(terraform output -raw bastion_public_ip)
EFS_DNS=$(terraform output -raw efs_dns_name)
A1=$(terraform output -raw app_a1_private_ip)
A2=$(terraform output -raw app_a2_private_ip)
B1=$(terraform output -raw app_b1_private_ip)
B2=$(terraform output -raw app_b2_private_ip)
DB=$(terraform output -raw db_private_ip)

cat > ansible/inventory.ini << INV
[bastion]
bastion ansible_host=${BASTION_IP}

[app]
app_a1 ansible_host=${A1}
app_a2 ansible_host=${A2}
app_b1 ansible_host=${B1}
app_b2 ansible_host=${B2}

[db]
db ansible_host=${DB}

[app:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${BASTION_IP} -o StrictHostKeyChecking=no'

[db:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${BASTION_IP} -o StrictHostKeyChecking=no'

[all:vars]
ansible_user=ubuntu
efs_dns_name=${EFS_DNS}
INV

echo "ansible/inventory.ini gerado."
