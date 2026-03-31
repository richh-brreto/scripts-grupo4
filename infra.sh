#!/bin/bash

# Variáveis
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"
REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
KEY_NAME="key-server"

echo "Buscando AMI Ubuntu"

AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  --query 'Images[*].[ImageId,CreationDate]' \
  --region $REGION \
  --output text | sort -k2 -r | head -n1 | cut -f1)

echo "AMI selecionada: $AMI_ID"

echo "Verificando Key Pair..."

if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION >/dev/null 2>&1; then
  echo "Criando Key Pair..."
  aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --region $REGION \
    --output text > ${KEY_NAME}.pem
  chmod 400 ${KEY_NAME}.pem
else
  echo "Key Pair já existe"
fi

echo "Criando VPC..."

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=VPC-LAB --region $REGION

echo "VPC criada: $VPC_ID"

echo "Criando Subnets..."

PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=Name,Value=Public-Subnet --region $REGION

PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $PRIVATE_SUBNET_ID --tags Key=Name,Value=Private-Subnet --region $REGION

echo "Subnets criadas"

echo "Criando Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=IGW-LAB --region $REGION

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $REGION >/dev/null

echo "Internet Gateway anexado"

echo "Configurando Route Table pública..."

RT_PUBLIC=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-tags --resources $RT_PUBLIC --tags Key=Name,Value=Public-RouteTable --region $REGION

aws ec2 create-route \
  --route-table-id $RT_PUBLIC \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION >/dev/null

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_ID \
  --route-table-id $RT_PUBLIC \
  --region $REGION >/dev/null

echo "Route Table pública configurada"

echo "Criando Elastic IP..."

EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --region $REGION \
  --query 'AllocationId' \
  --output text)

echo "Criando NAT Gateway..."

NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_ID \
  --allocation-id $EIP_ALLOC \
  --region $REGION \
  --query 'NatGateway.NatGatewayId' \
  --output text)

aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value=NAT-Gateway --region $REGION

echo "NAT Gateway criado: $NAT_GW_ID"

echo "Aguardando NAT Gateway ficar disponivel..."

aws ec2 wait nat-gateway-available \
  --nat-gateway-ids $NAT_GW_ID \
  --region $REGION

echo "NAT Gateway disponivel"

echo "Configurando Route Table privada..."

RT_PRIVATE=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-tags --resources $RT_PRIVATE --tags Key=Name,Value=Private-RouteTable --region $REGION

aws ec2 create-route \
  --route-table-id $RT_PRIVATE \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID \
  --region $REGION >/dev/null

aws ec2 associate-route-table \
  --subnet-id $PRIVATE_SUBNET_ID \
  --route-table-id $RT_PRIVATE \
  --region $REGION >/dev/null

echo "Route Table privada configurada"

echo "Criando Security Group pública..."

SG_PUBLIC_ID=$(aws ec2 create-security-group \
  --group-name public-sg \
  --description "Bastion SG" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 create-tags --resources $SG_PUBLIC_ID --tags Key=Name,Value=Bastion-SG --region $REGION

aws ec2 authorize-security-group-ingress \
  echo "Criando as regras de entrada no grupo de segurança..."
  aws ec2 authorize-security-group-ingress \
      --group-id $SG_PUBLIC_ID \
      --protocol tcp \
      --port 80 \
      --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-ingress \
      --group-id $SG_PUBLIC_ID \
      --protocol tcp \
      --port 443 \
      --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_PUBLIC_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

echo "Security Group púbico criado"

# security group para a instância de backend
echo "Criando Security group privada para BackEnd..."
SG_BACKEND_ID=$(aws ec2 create-security-group \
  --group-name private-backend-sg \
  --description "private-backend-SG" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 create-tags --resources $SG_BACKEND_ID --tags Key=Name,Value=private-backend-SG --region $REGION

aws ec2 authorize-security-group-ingress \
echo "Criando as regras de entrada no grupo de segurança..."

  aws ec2 authorize-security-group-ingress \
      --group-id $SG_BACKEND_ID \
      --protocol tcp \
      --port 80 \
      --cidr $PRIVATE_SUBNET_CIDR

  aws ec2 authorize-security-group-ingress \
      --group-id $SG_BACKEND_ID \
      --protocol tcp \
      --port 8080 \
      --cidr $PRIVATE_SUBNET_CIDR
  
  aws ec2 authorize-security-group-ingress \
      --group-id $SG_BACKEND_ID \
      --protocol tcp \
      --port 22 \
      --cidr $PRIVATE_SUBNET_CIDR

# security group para instância de BD
SG_DATABASE_ID=$(aws ec2 create-security-group \
  --group-name private-database-sg \
  --description "private-database-SG" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 create-tags --resources $SG_DATABASE_ID --tags Key=Name,Value=private-database-SG --region $REGION

aws ec2 authorize-security-group-ingress \
echo "Criando as regras de entrada no grupo de segurança..."

  aws ec2 authorize-security-group-ingress \
      --group-id $SG_DATABASE_ID \
      --protocol tcp \
      --port 3306 \
      --cidr $PRIVATE_SUBNET_CIDR
  
  aws ec2 authorize-security-group-ingress \
      --group-id $SG_DATABASE_ID \
      --protocol tcp \
      --port 22 \
      --cidr $PRIVATE_SUBNET_CIDR

echo "Subindo Bastion Host..."
BASTION_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PUBLIC_SUBNET_ID \
  --security-group-ids $SG_PUBLIC_ID \
  --associate-public-ip-address \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

aws ec2 create-tags \
  --resources $BASTION_ID \
  --tags Key=Name,Value=EC2-Publica-$BASTION_ID \
  --region $REGION

echo "Bastion Host criado: $BASTION_ID"

echo "Subindo 2 instâncias privadas..."

# subindo instância de backend
echo "Subindo instância do BackEnd"
BACKEND_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIVATE_SUBNET_ID \
  --security-group-ids $SG_BACKEND_ID \
  --region $REGION \
  --query 'Instances[*].InstanceId' \
  --output text)

aws ec2 create-tags \
    --resources $BACKEND_ID \
    --tags Key=Name,Value=EC2-BackEnd-$BACKEND_ID \
    --region $REGION

# subindo instância do banco de dados
DATABASE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIVATE_SUBNET_ID \
  --security-group-ids $SG_DATABASE_ID \
  --region $REGION \
  --query 'Instances[*].InstanceId' \
  --output text)

aws ec2 create-tags \
  --resources $DATABASE_ID \
  --tags Key=Name,Value=EC2-Database-$DATABASE_ID \
  --region $REGION

echo "Instâncias privadas criadas"

echo ""
echo "==============================="
echo "Infra criada com sucesso"
echo "1 EC2 Bastion Host (public)"
echo "2 EC2 (private)"
echo "NAT Gateway + VPC + Subnets"
echo "==============================="
