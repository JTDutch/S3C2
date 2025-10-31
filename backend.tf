terraform {
  backend "s3" {
    bucket         = "terraform-state-just-c2"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
