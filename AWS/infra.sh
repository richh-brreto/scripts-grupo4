#!/bin/bash
set -e

# Variáveis
VPC_CIDR="10.0.0.0/16"
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

echo "Criando VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

echo "Criando Subnets..."

PUB_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --region $REGION --query 'Subnet.SubnetId' --output text)
PUB_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.5.0/24 --availability-zone ${REGION}b --region $REGION --query 'Subnet.SubnetId' --output text)

PRIV_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${REGION}a --region $REGION --query 'Subnet.SubnetId' --output text)
PRIV_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone ${REGION}b --region $REGION --query 'Subnet.SubnetId' --output text)

DB_SUBNET=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone ${REGION}a --region $REGION --query 'Subnet.SubnetId' --output text)

echo "Criando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION >/dev/null

echo "Configurando Route Table pública..."
RT_PUBLIC=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $RT_PUBLIC --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION >/dev/null

aws ec2 associate-route-table --subnet-id $PUB_A --route-table-id $RT_PUBLIC --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $PUB_B --route-table-id $RT_PUBLIC --region $REGION >/dev/null

echo "Criando NAT Gateway..."
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --region $REGION --query 'AllocationId' --output text)

NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_A \
  --allocation-id $EIP_ALLOC \
  --region $REGION \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "Aguardando NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $REGION

echo "Configurando Route Table privada..."
RT_PRIVATE=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $RT_PRIVATE --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID --region $REGION >/dev/null

aws ec2 associate-route-table --subnet-id $PRIV_A --route-table-id $RT_PRIVATE --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $PRIV_B --route-table-id $RT_PRIVATE --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $DB_SUBNET --route-table-id $RT_PRIVATE --region $REGION >/dev/null

echo "Criando Security Groups..."
SG_PUBLIC=$(aws ec2 create-security-group --group-name public-sg --description "public" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_PUBLIC --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_PUBLIC --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_PUBLIC --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null

SG_BACK=$(aws ec2 create-security-group --group-name back-sg --description "backend" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_BACK --protocol tcp --port 80 --source-group $SG_PUBLIC >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_BACK --protocol tcp --port 8080 --source-group $SG_PUBLIC >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_BACK --protocol tcp --port 22 --source-group $SG_PUBLIC >/dev/null

SG_DB=$(aws ec2 create-security-group --group-name db-sg --description "db" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_DB --protocol tcp --port 3306 --source-group $SG_BACK >/dev/null

echo "Subindo EC2..."

# Bastion (publica)
BASTION=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PUB_A \
  --security-group-ids $SG_PUBLIC \
  --associate-public-ip-address \
  --private-ip-address 10.0.1.11 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

# PRIVATE A
APP_A1=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_A \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.2.11 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

APP_A2=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_A \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.2.12 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

# PRIVATE B
APP_B1=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_B \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.3.11 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

APP_B2=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_B \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.3.12 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

# DB
DB=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $DB_SUBNET \
  --security-group-ids $SG_DB \
  --private-ip-address 10.0.4.11 \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Aguardando instâncias..."
aws ec2 wait instance-running --instance-ids $APP_A1 $APP_A2 $APP_B1 $APP_B2 --region $REGION

echo "Criando ALB..."
ALB=$(aws elbv2 create-load-balancer \
  --name alb-lab-$(date +%s) \
  --subnets $PUB_A $PUB_B \
  --security-groups $SG_PUBLIC \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

TG=$(aws elbv2 create-target-group \
  --name tg-lab-$(date +%s) \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 register-targets \
  --target-group-arn $TG \
  --targets Id=$APP_A1 Id=$APP_A2 Id=$APP_B1 Id=$APP_B2 \
  --region $REGION >/dev/null

aws elbv2 create-listener \
  --load-balancer-arn $ALB \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG \
  --region $REGION >/dev/null

echo "Criando EFS..."
EFS=$(aws efs create-file-system --region $REGION --query 'FileSystemId' --output text)

sleep 20

aws efs create-mount-target --file-system-id $EFS --subnet-id $PRIV_A --security-groups $SG_BACK --region $REGION >/dev/null
aws efs create-mount-target --file-system-id $EFS --subnet-id $PRIV_B --security-groups $SG_BACK --region $REGION >/dev/null

echo ""
echo "==============================="
echo "Infra criada com sucesso"
echo "1 Bastion (publica)"
echo "2 EC2 Private A"
echo "2 EC2 Private B"
echo "1 DB"
echo "ALB + NAT + EFS"
echo "==============================="
