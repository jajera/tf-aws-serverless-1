data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["database*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["private*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["public*"]
  }
}

data "aws_vpc" "example" {
  id = local.vpc_id
}

data "aws_security_group" "ecs" {
  name = "serverless-ecs-${local.suffix}"
}

data "aws_security_group" "ssh" {
  name = "serverless-ssh-${local.suffix}"
}

resource "aws_security_group" "psql" {
  name   = "serverless-psql-${local.suffix}"
  vpc_id = data.aws_vpc.example.id

  ingress {
    description = "psql from private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = local.vpc_network.private_subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "serverless-psql-${local.suffix}"
  }
}
