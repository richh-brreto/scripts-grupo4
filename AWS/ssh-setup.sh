#!/bin/bash
set -e

# ==========================================
# Copia a chave SSH para a Bastion e configura
# ProxyJump para acessar instancias privadas
# ==========================================
REGION="us-east-1"
KEY_FILE="key-server.pem"

if [ ! -f "$KEY_FILE" ]; then
  echo "ERRO: Arquivo $KEY_FILE nao encontrado no diretorio atual."
  echo "Copie o arquivo .pem para este diretorio antes de executar."
  exit 1
fi

chmod 400 "$KEY_FILE"

echo "Buscando IP publico da Bastion..."
BASTION_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text 2>/dev/null | head -n1)

if [ -z "$BASTION_IP" ]; then
  echo "ERRO: Nenhuma instancia bastion encontrada ou sem IP publico."
  exit 1
fi

echo "Bastion IP: $BASTION_IP"
echo "Copiando chave para a Bastion..."

scp -o StrictHostKeyChecking=no -i "$KEY_FILE" "$KEY_FILE" ubuntu@"$BASTION_IP":/tmp/key-server.pem

ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$BASTION_IP" \
  "chmod 600 /tmp/key-server.pem && mkdir -p ~/.ssh && cp /tmp/key-server.pem ~/.ssh/key-server.pem"

echo "Chave copiada com sucesso."
echo ""
echo "Para acessar instancias privadas via bastion:"
echo "  ssh -J ubuntu@$BASTION_IP -i $KEY_FILE ubuntu@<IP_PRIVADA>"
echo ""
echo "Ou use o script connect.sh para conectar diretamente."
