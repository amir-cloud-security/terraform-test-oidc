provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket         = "test-bucket-35678989864"
    key            = "terraform/state"
    region         = "eu-west-1"
    encrypt        = true
  }
}

resource "aws_s3_bucket" "test-bucket121314214" {
  bucket = "example-terraform-bucket"
  acl    = "private"
}
