output "suffix" {
  value = random_string.suffix.result
}

output "vpc_id" {
  value = aws_vpc.example.id
}

output "vpc_network" {
  value = var.vpc_network
}
