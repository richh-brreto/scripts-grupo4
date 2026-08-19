resource "aws_efs_file_system" "this" {
  creation_token = "${var.project_name}-efs"
  tags = { Name = "${var.project_name}-efs" }
}

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs.id]
}
