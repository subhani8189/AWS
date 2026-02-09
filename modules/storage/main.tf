resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "raw" {
  bucket = "raw-data-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "processed" {
  bucket = "processed-data-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

output "raw_bucket_id" { value = aws_s3_bucket.raw.id }
output "raw_bucket_arn" { value = aws_s3_bucket.raw.arn }
output "processed_bucket_id" { value = aws_s3_bucket.processed.id }
output "processed_bucket_arn" { value = aws_s3_bucket.processed.arn }