region      = "us-east-1"
environment = "dev"

vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24"
]

app_subnet_cidrs = [
  "10.20.11.0/24",
  "10.20.12.0/24"
]

db_subnet_cidrs = [
  "10.20.21.0/24",
  "10.20.22.0/24"
]