resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

variable "vpc_network" {
  description = "CIDR blocks for the VPC and its subnets"
  default = {
    entire_block     = "10.0.0.0/16"
    database_subnets = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
    private_subnets  = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
    public_subnets   = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  }
}
