#!/bin/bash

REGION="us-east-1"

echo "========================================="
echo " Limpando infraestrutura AWS (mantendo KeyPairs)"
echo " Região: $REGION"
echo "========================================="

# 1️⃣ Terminar instâncias
echo "🔹 Terminando instâncias EC2..."

INST_IDS=$(aws ec2 describe-instances \
--query 'Reservations[*].Instances[?State.Name!=`terminated`].InstanceId' \
--output text \
--region $REGION)

if [ -n "$INST_IDS" ]; then
  aws ec2 terminate-instances \
  --instance-ids $INST_IDS \
  --region $REGION >/dev/null

  echo "Aguardando instâncias finalizarem..."
  aws ec2 wait instance-terminated \
  --instance-ids $INST_IDS \
  --region $REGION

  echo "Instâncias removidas"
else
  echo "Nenhuma instância encontrada"
fi


# 2️⃣ Deletar NAT Gateway
echo "🔹 Deletando NAT Gateways..."

NAT_IDS=$(aws ec2 describe-nat-gateways \
--query 'NatGateways[?State!=`deleted`].NatGatewayId' \
--output text \
--region $REGION)

for nat in $NAT_IDS
do
  aws ec2 delete-nat-gateway \
  --nat-gateway-id $nat \
  --region $REGION >/dev/null

  echo "NAT Gateway $nat deletando..."
done

if [ -n "$NAT_IDS" ]; then
  echo "Aguardando NAT Gateway finalizar..."
  aws ec2 wait nat-gateway-deleted \
  --nat-gateway-ids $NAT_IDS \
  --region $REGION
fi


# 3️⃣ Liberar Elastic IPs
echo "🔹 Liberando Elastic IPs..."

EIPS=$(aws ec2 describe-addresses \
--query 'Addresses[*].AllocationId' \
--output text \
--region $REGION)

for eip in $EIPS
do
  aws ec2 release-address \
  --allocation-id $eip \
  --region $REGION >/dev/null
done


# 4️⃣ Security Groups
echo "🔹 Deletando Security Groups..."

SGS=$(aws ec2 describe-security-groups \
--query 'SecurityGroups[?GroupName!=`default`].GroupId' \
--output text \
--region $REGION)

for sg in $SGS
do
  aws ec2 delete-security-group \
  --group-id $sg \
  --region $REGION >/dev/null 2>&1
done


# 5️⃣ Route Tables
echo "🔹 Deletando Route Tables customizadas..."

RTS=$(aws ec2 describe-route-tables \
--query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
--output text \
--region $REGION)

for rt in $RTS
do

  ASSOC=$(aws ec2 describe-route-tables \
  --route-table-ids $rt \
  --query 'RouteTables[0].Associations[*].RouteTableAssociationId' \
  --output text \
  --region $REGION)

  for a in $ASSOC
  do
    aws ec2 disassociate-route-table \
    --association-id $a \
    --region $REGION >/dev/null 2>&1
  done

  aws ec2 delete-route-table \
  --route-table-id $rt \
  --region $REGION >/dev/null 2>&1
done


# 6️⃣ Internet Gateway
echo "🔹 Deletando Internet Gateways..."

IGWS=$(aws ec2 describe-internet-gateways \
--query 'InternetGateways[*].InternetGatewayId' \
--output text \
--region $REGION)

for igw in $IGWS
do

  VPC_ID=$(aws ec2 describe-internet-gateways \
  --internet-gateway-ids $igw \
  --query 'InternetGateways[0].Attachments[0].VpcId' \
  --output text \
  --region $REGION)

  if [ "$VPC_ID" != "None" ]; then
    aws ec2 detach-internet-gateway \
    --internet-gateway-id $igw \
    --vpc-id $VPC_ID \
    --region $REGION >/dev/null
  fi

  aws ec2 delete-internet-gateway \
  --internet-gateway-id $igw \
  --region $REGION >/dev/null
done


# 7️⃣ Subnets
echo "🔹 Deletando Subnets..."

SUBNETS=$(aws ec2 describe-subnets \
--query 'Subnets[*].SubnetId' \
--output text \
--region $REGION)

for sn in $SUBNETS
do
  aws ec2 delete-subnet \
  --subnet-id $sn \
  --region $REGION >/dev/null 2>&1
done


# 8️⃣ VPC
echo "🔹 Deletando VPCs customizadas..."

VPCS=$(aws ec2 describe-vpcs \
--query 'Vpcs[?IsDefault==`false`].VpcId' \
--output text \
--region $REGION)

for vpc in $VPCS
do
  aws ec2 delete-vpc \
  --vpc-id $vpc \
  --region $REGION >/dev/null
done


echo ""
echo "========================================="
echo " Limpeza concluída"
echo " Key Pairs foram preservadas"
echo "========================================="
