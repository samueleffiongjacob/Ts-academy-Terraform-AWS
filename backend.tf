terraform {
  backend "s3" {
    bucket       = "ts-academy-state-file"
    key          = "tf-academy.tfstate"
    region       = "us-east-1"
  }
}