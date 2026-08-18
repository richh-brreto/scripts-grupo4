#!/bin/bash
set -e

# Requer awslocal (pip install awscli-local) e LocalStack rodando (localstack start)

REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
KEY_NAME="key-server"

echo "Buscando AMI "
AMI_ID=$(awslocal ec2 describe-images --query 'Images[0].ImageId' --output text)
echo "Usando AMI: $AMI_ID"

echo "Criando VPC e subnets"
VPC_ID=$(awslocal ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)

PUB_SUBNET=$(awslocal ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text)
PRIV_SUBNET=$(awslocal ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --query 'Subnet.SubnetId' --output text)

echo "Criando Security Group"
SG_ID=$(awslocal ec2 create-security-group --group-name app-sg --description "app" --vpc-id $VPC_ID --query 'GroupId' --output text)
awslocal ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "Lançando instâncias"
APP1=$(awslocal ec2 run-instances --image-id $AMI_ID --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME --subnet-id $PRIV_SUBNET --security-group-ids $SG_ID \
  --query 'Instances[0].InstanceId' --output text)

APP2=$(awslocal ec2 run-instances --image-id $AMI_ID --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME --subnet-id $PRIV_SUBNET --security-group-ids $SG_ID \
  --query 'Instances[0].InstanceId' --output text)

echo "Configurando Load Balancer"
ALB_ARN=$(awslocal elbv2 describe-load-balancers --names alb-infra \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
if [ "$ALB_ARN" == "None" ] || [ -z "$ALB_ARN" ]; then
  ALB_ARN=$(awslocal elbv2 create-load-balancer --name alb-infra \
    --subnets $PUB_SUBNET --security-groups $SG_ID \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
fi

TG_ARN=$(awslocal elbv2 describe-target-groups --names tg-backend \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
if [ "$TG_ARN" == "None" ] || [ -z "$TG_ARN" ]; then
  TG_ARN=$(awslocal elbv2 create-target-group --name tg-backend \
    --protocol HTTP --port 80 --vpc-id $VPC_ID \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

awslocal elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$APP1 Id=$APP2

if ! awslocal elbv2 describe-listeners --load-balancer-arn $ALB_ARN \
  --query 'Listeners[0].ListenerArn' --output text 2>/dev/null | grep -q arn; then
  awslocal elbv2 create-listener --load-balancer-arn $ALB_ARN \
    --protocol HTTP --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN
fi

echo "Infra simplificada criada"
