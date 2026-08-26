data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y && apt-get install -y nfs-common
    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.this.dns_name}:/ /mnt/efs
    echo "${aws_efs_file_system.this.dns_name}:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab
  EOT

  app_instances = {
    a1 = { subnet_id = aws_subnet.private_a.id, ip = "10.0.2.11" } ## front
    a2 = { subnet_id = aws_subnet.private_a.id, ip = "10.0.2.12" } ## back
    b1 = { subnet_id = aws_subnet.private_b.id, ip = "10.0.3.11" } ## front 
    b2 = { subnet_id = aws_subnet.private_b.id, ip = "10.0.3.12" } ## back
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  private_ip                  = "10.0.1.11"
  user_data_base64            = base64encode(local.user_data)
  tags = { Name = "${var.project_name}-bastion" }
}

resource "aws_instance" "app" {
  for_each                = local.app_instances
  ami                      = data.aws_ami.ubuntu.id
  instance_type            = var.instance_type
  key_name                 = var.key_name
  subnet_id                = each.value.subnet_id
  vpc_security_group_ids   = [aws_security_group.backend.id]
  private_ip               = each.value.ip
  user_data_base64          = base64encode(local.user_data)
  tags = { Name = "${var.project_name}-app-${each.key}" }
}

resource "aws_instance" "db" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  key_name                = var.key_name
  subnet_id               = aws_subnet.db.id
  vpc_security_group_ids  = [aws_security_group.db.id]
  private_ip              = "10.0.4.11"
  user_data_base64         = base64encode(local.user_data)
  tags = { Name = "${var.project_name}-db" }
}
