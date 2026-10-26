#!/bin/bash
# =====================================================================
#  Instala e configura o Fluent Bit numa instância Ubuntu do Grupo 4.
#
#  Uso (na instância, com os arquivos desta pasta ao lado do script):
#    sudo NODE_NAME=boost-app-a1 NODE_ROLE=front \
#         BRONZE_BUCKET=<nome-do-bucket-bronze> ./install-fluent-bit.sh
#
#  Variáveis:
#    NODE_NAME      nome da máquina nos logs (obrigatória)
#    NODE_ROLE      front | back | db | bastion (obrigatória)
#    BRONZE_BUCKET  bucket bronze (obrigatória)
#    AWS_REGION     padrão us-east-1
#    AMBIENTE       padrão dev
#    RESTART_DOCKER 1 (padrão) reinicia o Docker para aplicar o log-driver
#
#  Credenciais: o Fluent Bit usa o perfil da instância (LabInstanceProfile).
# =====================================================================
set -euo pipefail

: "${NODE_NAME:?defina NODE_NAME}"
: "${NODE_ROLE:?defina NODE_ROLE}"
: "${BRONZE_BUCKET:?defina BRONZE_BUCKET}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AMBIENTE="${AMBIENTE:-dev}"
RESTART_DOCKER="${RESTART_DOCKER:-1}"
FLB_VERSION="${FLB_VERSION:-3.2.10}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Execute com sudo"; exit 1; }

echo ">> [1/5] Instalando Fluent Bit"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -qq
apt-get install -y -qq curl gnupg ca-certificates python3 >/dev/null
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
curl -fsSL https://packages.fluentbit.io/fluentbit.key \
  | gpg --dearmor --yes -o /usr/share/keyrings/fluentbit-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/${CODENAME} ${CODENAME} main" \
  > /etc/apt/sources.list.d/fluent-bit.list
apt-get update -y -qq
if apt-cache madison fluent-bit | grep -q " ${FLB_VERSION} "; then
  apt-get install -y -qq "fluent-bit=${FLB_VERSION}" >/dev/null
else
  echo "   versão ${FLB_VERSION} indisponível para ${CODENAME}; instalando a mais recente"
  apt-get install -y -qq fluent-bit >/dev/null
fi

echo ">> [2/5] Copiando configuração"
install -d -m 0755 /etc/fluent-bit /var/lib/fluent-bit/storage /var/lib/fluent-bit/s3
install -m 0644 "$SRC_DIR/fluent-bit.conf"     /etc/fluent-bit/fluent-bit.conf
install -m 0644 "$SRC_DIR/parsers-boost.conf"  /etc/fluent-bit/parsers-boost.conf
install -m 0644 "$SRC_DIR/boost.lua"           /etc/fluent-bit/boost.lua
cat > /etc/fluent-bit/boost-env.conf <<EOF
@SET NODE_NAME=${NODE_NAME}
@SET NODE_ROLE=${NODE_ROLE}
@SET BRONZE_BUCKET=${BRONZE_BUCKET}
@SET AWS_REGION=${AWS_REGION}
@SET AMBIENTE=${AMBIENTE}
EOF

FLB_BIN=/opt/fluent-bit/bin/fluent-bit
"$FLB_BIN" -c /etc/fluent-bit/fluent-bit.conf --dry-run

echo ">> [3/5] Iniciando o serviço fluent-bit"
systemctl enable fluent-bit >/dev/null 2>&1
systemctl restart fluent-bit
for i in $(seq 1 15); do
  curl -fs http://127.0.0.1:2020/api/v1/health >/dev/null 2>&1 && break
  sleep 1
done
systemctl is-active --quiet fluent-bit && echo "   fluent-bit ativo"

echo ">> [4/5] Configurando o Docker para enviar os logs ao Fluent Bit"
install -d -m 0755 /etc/docker
python3 - "$SRC_DIR/docker-daemon.json" <<'PY'
import json, os, sys
novo = json.load(open(sys.argv[1]))
caminho = "/etc/docker/daemon.json"
atual = {}
if os.path.exists(caminho) and os.path.getsize(caminho) > 0:
    atual = json.load(open(caminho))
atual.update(novo)          # mantém outras chaves já existentes
json.dump(atual, open(caminho, "w"), indent=2)
print("   /etc/docker/daemon.json atualizado")
PY
if command -v docker >/dev/null 2>&1 && [ "$RESTART_DOCKER" = "1" ]; then
  systemctl restart docker
  echo "   docker reiniciado (containers existentes só mudam de driver ao serem recriados)"
else
  echo "   docker ainda não instalado ou reinício desativado; o driver vale quando ele subir"
fi

echo ">> [5/5] Verificação"
"$FLB_BIN" --version | head -1
curl -s http://127.0.0.1:2020/api/v1/health; echo
command -v docker >/dev/null 2>&1 && docker info --format 'log-driver do docker: {{.LoggingDriver}}' || true
echo "Pronto. Os primeiros arquivos chegam ao S3 em até 5 minutos (upload_timeout)."
