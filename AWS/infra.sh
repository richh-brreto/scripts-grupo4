#!/bin/bash
set -e

# ==========================================
# 1. VARIÁVEIS E DEFINIÇÕES
# ==========================================
VPC_CIDR="10.0.0.0/16"
REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
KEY_NAME="key-server"

echo "Buscando AMI Ubuntu Noble 24.04..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  --query 'Images[*].[ImageId,CreationDate]' \
  --region $REGION \
  --output text | sort -k2 -r | head -n1 | cut -f1)

# ==========================================
# 2. INFRAESTRUTURA DE REDE (VPC & SUBNETS)
# ==========================================
echo "Criando VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support "{\"Value\":true}" \
  --region $REGION >/dev/null

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION >/dev/null

echo "Criando Subnets..."
PUB_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PUB_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.5.0/24 \
  --availability-zone ${REGION}b \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PRIV_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PRIV_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone ${REGION}b \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

DB_SUBNET=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.4.0/24 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

# ==========================================
# 3. GATEWAYS E ROTEAMENTO (NAT PARA DB/PRIV)
# ==========================================
echo "Configurando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $REGION >/dev/null

echo "Configurando NAT Gateway..."
EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --region $REGION \
  --query 'AllocationId' \
  --output text)

NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_A \
  --allocation-id $EIP_ALLOC \
  --region $REGION \
  --query 'NatGateway.NatGatewayId' \
  --output text)

RT_PUBLIC=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $RT_PUBLIC \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION >/dev/null

aws ec2 associate-route-table --subnet-id $PUB_A --route-table-id $RT_PUBLIC --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $PUB_B --route-table-id $RT_PUBLIC --region $REGION >/dev/null

aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $REGION

RT_PRIVATE=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $RT_PRIVATE \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID \
  --region $REGION >/dev/null

aws ec2 associate-route-table --subnet-id $PRIV_A --route-table-id $RT_PRIVATE --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $PRIV_B --route-table-id $RT_PRIVATE --region $REGION >/dev/null
aws ec2 associate-route-table --subnet-id $DB_SUBNET --route-table-id $RT_PRIVATE --region $REGION >/dev/null

# ==========================================
# 4. SECURITY GROUPS
# ==========================================
echo "Criando Grupos de Segurança..."

SG_ALB=$(aws ec2 create-security-group \
  --group-name alb-sg \
  --description "ALB" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ALB \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION >/dev/null

SG_BASTION=$(aws ec2 create-security-group \
  --group-name bastion-sg \
  --description "Bastion" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_BASTION \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $REGION >/dev/null

SG_BACK=$(aws ec2 create-security-group \
  --group-name back-sg \
  --description "Backend" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_BACK \
  --protocol tcp \
  --port 80 \
  --source-group $SG_ALB \
  --region $REGION >/dev/null

aws ec2 authorize-security-group-ingress \
  --group-id $SG_BACK \
  --protocol tcp \
  --port 22 \
  --source-group $SG_BASTION \
  --region $REGION >/dev/null

SG_DB=$(aws ec2 create-security-group \
  --group-name db-sg \
  --description "DB" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_DB \
  --protocol tcp \
  --port 3306 \
  --source-group $SG_BACK \
  --region $REGION >/dev/null

SG_EFS=$(aws ec2 create-security-group \
  --group-name efs-sg \
  --description "EFS" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_EFS \
  --protocol tcp \
  --port 2049 \
  --cidr 10.0.0.0/16 \
  --region $REGION >/dev/null

# ==========================================
# 5. ARMAZENAMENTO (AMAZON EFS)
# ==========================================
echo "Provisionando EFS..."
EFS_ID=$(aws efs create-file-system \
  --creation-token efs-lab \
  --region $REGION \
  --query 'FileSystemId' \
  --output text)

sleep 15

aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $PRIV_A \
  --security-groups $SG_EFS \
  --region $REGION >/dev/null

aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $PRIV_B \
  --security-groups $SG_EFS \
  --region $REGION >/dev/null

USER_DATA=$(base64 <<EOF
#!/bin/bash
apt-get update -y && apt-get install -y nfs-common
mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS_ID.efs.$REGION.amazonaws.com:/ /mnt/efs
echo "$EFS_ID.efs.$REGION.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab
EOF
)

# ==========================================
# 6. COMPUTAÇÃO (EC2)
# ==========================================
echo "Lançando Instâncias..."

BASTION=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PUB_A \
  --security-group-ids $SG_BASTION \
  --associate-public-ip-address \
  --private-ip-address 10.0.1.11 \
  --user-data "$USER_DATA" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

APP_A1=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_A \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.2.11 \
  --user-data "$USER_DATA" \
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
  --user-data "$USER_DATA" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

APP_B1=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $PRIV_B \
  --security-group-ids $SG_BACK \
  --private-ip-address 10.0.3.11 \
  --user-data "$USER_DATA" \
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
  --user-data "$USER_DATA" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

DB_INST=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id $DB_SUBNET \
  --security-group-ids $SG_DB \
  --private-ip-address 10.0.4.11 \
  --user-data "$USER_DATA" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

# ==========================================
# 7. BALANCEAMENTO (ALB - APENAS A2 E B2)
# ==========================================
echo "Aguardando instâncias A2 e B2 para registro..."
aws ec2 wait instance-running \
  --instance-ids $APP_A2 $APP_B2 \
  --region $REGION

echo "Configurando Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name alb-infra \
  --subnets $PUB_A $PUB_B \
  --security-groups $SG_ALB \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

TG_ARN=$(aws elbv2 create-target-group \
  --name tg-backend \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$APP_A2 Id=$APP_B2 \
  --region $REGION >/dev/null

aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION >/dev/null

echo "Infraestrutura provisionada com sucesso."
