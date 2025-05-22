resource "random_id" "bucket_suffix" {
  byte_length = 2
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "amr-terraform-test-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
}