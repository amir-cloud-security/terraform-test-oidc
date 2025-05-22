terraform {
  backend "s3" {
    bucket         = "test-bucket-35678989864"
    key            = "terraform/state"
    region         = "eu-west-1"
    encrypt        = true
  }
}