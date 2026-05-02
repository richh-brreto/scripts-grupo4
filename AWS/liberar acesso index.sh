#!/bin/bash

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
  <title>EC2 Info</title>
</head>
<body style="background:#0f172a;color:white;text-align:center;margin-top:50px">
  <h1>🚀 EC2 Info</h1>
  <p>IP Privado: $IP</p>
  <p>Availability Zone: $AZ</p>
</body>
</html>
EOF

systemctl restart nginx
