terraform {
  backend "s3" {
    bucket         = "my-secure-tf-state-235423434"
    key            = "terraform/state"
    region         = "eu-west-1"
    encrypt        = true
  }
}
