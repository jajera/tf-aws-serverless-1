resource "aws_vpc" "example" {
  cidr_block           = var.vpc_network.entire_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "serverless-${random_string.suffix.result}"
  }
}

resource "aws_subnet" "database" {
  count             = length(var.vpc_network.database_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.database_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name = "database-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.vpc_network.private_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.private_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name = "private-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.vpc_network.public_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.public_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}


resource "aws_default_network_acl" "example" {
  default_network_acl_id = aws_vpc.example.default_network_acl_id

  egress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }
  egress {
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
  }

  ingress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }
  ingress {
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
  }

  lifecycle {
    ignore_changes = [
      subnet_ids
    ]
  }

  tags = {
    Name = "serverless-${random_string.suffix.result}"
  }
}

resource "aws_default_route_table" "example" {
  default_route_table_id = aws_vpc.example.default_route_table_id

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = {
    Name = "default-${random_string.suffix.result}"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "serverless-${random_string.suffix.result}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "serverless-${random_string.suffix.result}"
  }
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.example
  ]
}

resource "aws_route_table_association" "database" {
  count          = length(var.vpc_network.database_subnets)
  route_table_id = aws_route_table.database.id
  subnet_id      = aws_subnet.database[count.index].id
}

resource "aws_ec2_instance_connect_endpoint" "example" { 
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "serverless-${random_string.suffix.result}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example.id
  }

  tags = {
    Name = "private-${random_string.suffix.result}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.vpc_network.private_subnets)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "public-${random_string.suffix.result}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.vpc_network.private_subnets)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example.id
  }

  tags = {
    Name = "private-${random_string.suffix.result}"
  }
}

resource "aws_security_group" "ssh" {
  name   = "serverless-ssh-${random_string.suffix.result}"
  vpc_id = aws_vpc.example.id

  ingress {
    description = "ssh from private subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }

  ingress {
    description = "ssh from anywhere" # for testing only. apply granular filter
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "serverless-ssh-${random_string.suffix.result}"
  }
}
