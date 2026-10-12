locals {
  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y && apt-get install -y nfs-common curl unzip docker.io

    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.this.dns_name}:/ /mnt/efs
    echo "${aws_efs_file_system.this.dns_name}:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab
  EOT
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0574d0702e5afbe82" # bastion
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  private_ip                  = "10.0.1.11"
  user_data_base64            = base64encode(local.user_data)
  tags                        = { Name = "${var.project_name}-bastion" }
}

resource "aws_instance" "back_a1" {
  ami                    = "ami-0af18df0f9f26eb3e" # backend-a1
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.0.2.11"
  user_data_base64       = base64encode(local.user_data)
  tags                   = { Name = "${var.project_name}-back-a1" }
}

resource "aws_instance" "front_a2" {
  ami                    = "ami-02274471ac5ff9db5" # frontend-a2
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  private_ip             = "10.0.2.12"
  user_data_base64       = base64encode(local.user_data)
  tags                   = { Name = "${var.project_name}-front-a2" }
}

resource "aws_instance" "back_b1" {
  ami                    = "ami-09a4ffd5da22ab8a4" # backend-b1
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.0.3.11"
  user_data_base64       = base64encode(local.user_data)
  tags                   = { Name = "${var.project_name}-back-b1" }
}

resource "aws_instance" "front_b2" {
  ami                    = "ami-0046b2f3e8c9a7ebe" # frontend-b2
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  private_ip             = "10.0.3.12"
  user_data_base64       = base64encode(local.user_data)
  tags                   = { Name = "${var.project_name}-front-b2" }
}

resource "aws_instance" "db" {
  ami                    = "ami-0248dcc226dc34d3a" # Data Base
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  private_ip             = "10.0.4.11"
  user_data_base64       = base64encode(local.user_data)
  tags                   = { Name = "${var.project_name}-db" }
}

moved {
  from = aws_instance.front_a1
  to   = aws_instance.back_a1
}
moved {
  from = aws_instance.back_a2
  to   = aws_instance.front_a2
}
moved {
  from = aws_instance.front_b1
  to   = aws_instance.back_b1
}
moved {
  from = aws_instance.back_b2
  to   = aws_instance.front_b2
}