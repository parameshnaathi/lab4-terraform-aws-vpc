terraform {
  backend "s3" {
    bucket       = "paramesh-arrise-tfstate-12345"
    key          = "arrise/dev/network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}