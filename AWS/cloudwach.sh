#!/bin/bash

set -e

REGION="us-east-1"
DASHBOARD_NAME="Grupo4-Infraestrutura"

echo "========================================="
echo " Descobrindo recursos AWS"
echo "========================================="

# EC2
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

# EFS
EFS_ID=$(aws efs describe-file-systems \
  --region "$REGION" \
  --query 'FileSystems[0].FileSystemId' \
  --output text)

# ALB CloudWatch dimension
ALB_DIMENSION=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text | sed 's#.*loadbalancer/##')

echo "ALB: $ALB_DIMENSION"
echo "EFS: $EFS_ID"
echo "EC2: $INSTANCE_IDS"

echo "========================================="
echo " Gerando Dashboard"
echo "========================================="

cat > dashboard.json <<EOF
{
  "widgets": [
EOF

COUNT=0
X=0
Y=0

for INSTANCE in $INSTANCE_IDS
do
  if [ $COUNT -gt 0 ]; then
    echo "," >> dashboard.json
  fi

  cat >> dashboard.json <<EOF
{
  "type":"metric",
  "x":$X,
  "y":$Y,
  "width":12,
  "height":6,
  "properties":{
    "title":"CPU $INSTANCE",
    "metrics":[
      ["AWS/EC2","CPUUtilization","InstanceId","$INSTANCE"]
    ],
    "region":"$REGION",
    "stat":"Average",
    "period":300
  }
}
EOF

  COUNT=$((COUNT+1))

  if [ $X -eq 0 ]; then
    X=12
  else
    X=0
    Y=$((Y+6))
  fi
done

cat >> dashboard.json <<EOF
,
{
  "type":"metric",
  "x":0,
  "y":$((Y+6)),
  "width":12,
  "height":6,
  "properties":{
    "title":"ALB Requests",
    "metrics":[
      ["AWS/ApplicationELB","RequestCount","LoadBalancer","$ALB_DIMENSION"]
    ],
    "region":"$REGION",
    "stat":"Sum"
  }
},
{
  "type":"metric",
  "x":12,
  "y":$((Y+6)),
  "width":12,
  "height":6,
  "properties":{
    "title":"ALB Latency",
    "metrics":[
      ["AWS/ApplicationELB","TargetResponseTime","LoadBalancer","$ALB_DIMENSION"]
    ],
    "region":"$REGION",
    "stat":"Average"
  }
},
{
  "type":"metric",
  "x":0,
  "y":$((Y+12)),
  "width":12,
  "height":6,
  "properties":{
    "title":"ALB HTTP 5XX",
    "metrics":[
      ["AWS/ApplicationELB","HTTPCode_ELB_5XX_Count","LoadBalancer","$ALB_DIMENSION"]
    ],
    "region":"$REGION",
    "stat":"Sum"
  }
},
{
  "type":"metric",
  "x":12,
  "y":$((Y+12)),
  "width":12,
  "height":6,
  "properties":{
    "title":"EFS Throughput",
    "metrics":[
      ["AWS/EFS","TotalIOBytes","FileSystemId","$EFS_ID"]
    ],
    "region":"$REGION",
    "stat":"Sum"
  }
}
]
}
EOF

echo "Validando JSON..."
python3 -m json.tool dashboard.json >/dev/null

echo "Criando Dashboard..."

aws cloudwatch put-dashboard \
  --region "$REGION" \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body file://dashboard.json

echo "========================================="
echo " Dashboard criado com sucesso!"
echo "========================================="
echo "CloudWatch > Dashboards > $DASHBOARD_NAME"
