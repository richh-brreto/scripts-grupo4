locals {
  medallion_layers = ["bronze", "silver", "gold"]
}

resource "aws_s3_bucket" "medallion" {
  for_each = toset(local.medallion_layers)

  bucket = "${var.project_name}-${each.key}-${var.environment}"

  tags = {
    Layer       = each.key
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "medallion" {
  for_each = aws_s3_bucket.medallion

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "medallion" {
  for_each = aws_s3_bucket.medallion

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
