#!/bin/bash
set -e

REGION="us-east-1"
KEY_FILE="key-server.pem"

if [ ! -f "$KEY_FILE" ]; then
  echo "ERRO: Arquivo $KEY_FILE nao encontrado."
  exit 1
fi

chmod 400 "$KEY_FILE"

# Mapeamento de hostnames para IPs privados
case "$1" in
  bastion)
    TARGET_IP=""
    ;;
  app-a1)
    TARGET_IP="10.0.2.11"
    ;;
  app-a2)
    TARGET_IP="10.0.2.12"
    ;;
  app-b1)
    TARGET_IP="10.0.3.11"
    ;;
  app-b2)
    TARGET_IP="10.0.3.12"
    ;;
  db)
    TARGET_IP="10.0.4.11"
    ;;
  *)
    echo "Uso: $0 <destino>"
    echo ""
    echo "Destinos disponiveis:"
    echo "  bastion  - Acessar bastion (IP publico)"
    echo "  app-a1   - App server A1 (privado)"
    echo "  app-a2   - App server A2 (privado)"
    echo "  app-b1   - App server B1 (privado)"
    echo "  app-b2   - App server B2 (privado)"
    echo "  db       - Database server (privado)"
    exit 1
    ;;
esac

BASTION_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text 2>/dev/null | head -n1)

if [ -z "$BASTION_IP" ]; then
  echo "ERRO: Nenhuma instancia bastion encontrada."
  exit 1
fi

if [ "$1" = "bastion" ]; then
  echo "Conectando na Bastion ($BASTION_IP)..."
  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$BASTION_IP"
else
  echo "Conectando em $1 ($TARGET_IP) via Bastion ($BASTION_IP)..."
  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" \
    -o ProxyCommand="ssh -o StrictHostKeyChecking=no -i %i ubuntu@$BASTION_IP -W %h:%p" \
    ubuntu@"$TARGET_IP"
fi
