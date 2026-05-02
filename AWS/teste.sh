#!/bin/bash

REGION="us-east-1"

echo "========================================="
echo " EC2 + Availability Zone"
echo " Região: $REGION"
echo " (RUNNING ordenado por IP PRIVADO)"
echo "========================================="

aws ec2 describe-instances \
--region $REGION \
--filters "Name=instance-state-name,Values=running" \
--query 'sort_by(Reservations[].Instances[], &PrivateIpAddress)[].[InstanceId,Placement.AvailabilityZone,State.Name,PublicIpAddress,PrivateIpAddress]' \
--output table
