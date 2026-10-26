output "buckets" {
  value = { for camada, b in aws_s3_bucket.medallion : camada => b.id }
}
