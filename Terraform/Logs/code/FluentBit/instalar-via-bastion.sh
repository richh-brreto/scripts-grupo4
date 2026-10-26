#!/bin/bash
# =====================================================================
#  Instala o Fluent Bit nas instâncias JÁ EXISTENTES, passando pela bastion.
#  (Instâncias novas criadas pelo Terraform já instalam sozinhas via user_data.)
#
#  Rode a partir desta pasta (FluentBit/), no Git Bash/WSL/Linux, com o
#  key-server.pem na mesma pasta e o AWS CLI configurado:
#    ./instalar-via-bastion.sh <bucket-bronze> [destinos...]
#  Exemplo:
#    ./instalar-via-bastion.sh infra-lab-bronze-dev               # todas
#    ./instalar-via-bastion.sh infra-lab-bronze-dev app-a1 app-b1 # só algumas
# =====================================================================
set -e

REGION="us-east-1"
KEY_FILE="key-server.pem"
PROJECT="${PROJECT:-Boost}"
BUCKET="${1:?informe o bucket bronze}"; shift || true
DESTINOS="${*:-bastion app-a1 app-a2 app-b1 app-b2 db}"

[ -f "$KEY_FILE" ] || { echo "ERRO: $KEY_FILE não encontrado nesta pasta"; exit 1; }
chmod 400 "$KEY_FILE"

BASTION_IP=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=*bastion*" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' --output text | head -n1)
[ -n "$BASTION_IP" ] || { echo "ERRO: bastion não encontrada"; exit 1; }
echo "Bastion: $BASTION_IP"

SSH_OPTS=(-o StrictHostKeyChecking=no -i "$KEY_FILE")
PROXY=(-o "ProxyCommand=ssh -o StrictHostKeyChecking=no -i $KEY_FILE -W %h:%p ubuntu@$BASTION_IP")
ARQUIVOS=(fluent-bit.conf parsers-boost.conf boost.lua docker-daemon.json install-fluent-bit.sh)

for destino in $DESTINOS; do
  case "$destino" in
    bastion) IP="$BASTION_IP"; ROLE=bastion; EXTRA=() ;;
    app-a1)  IP=10.0.2.11; ROLE=front; EXTRA=("${PROXY[@]}") ;;
    app-b1)  IP=10.0.3.11; ROLE=front; EXTRA=("${PROXY[@]}") ;;
    app-a2)  IP=10.0.2.12; ROLE=back;  EXTRA=("${PROXY[@]}") ;;
    app-b2)  IP=10.0.3.12; ROLE=back;  EXTRA=("${PROXY[@]}") ;;
    db)      IP=10.0.4.11; ROLE=db;    EXTRA=("${PROXY[@]}") ;;
    *) echo "destino desconhecido: $destino"; continue ;;
  esac
  NODE="${PROJECT}-${destino}"
  echo "=============================================="
  echo " $NODE ($IP) role=$ROLE"
  echo "=============================================="
  ssh "${SSH_OPTS[@]}" "${EXTRA[@]}" ubuntu@"$IP" "mkdir -p /tmp/boost-fluent-bit"
  scp "${SSH_OPTS[@]}" "${EXTRA[@]}" "${ARQUIVOS[@]}" ubuntu@"$IP":/tmp/boost-fluent-bit/
  ssh "${SSH_OPTS[@]}" "${EXTRA[@]}" ubuntu@"$IP" \
    "chmod +x /tmp/boost-fluent-bit/install-fluent-bit.sh && sudo NODE_NAME=$NODE NODE_ROLE=$ROLE BRONZE_BUCKET=$BUCKET AWS_REGION=$REGION /tmp/boost-fluent-bit/install-fluent-bit.sh"
done
