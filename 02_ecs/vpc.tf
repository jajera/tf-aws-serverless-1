data "aws_vpc" "example" {
  id = local.vpc_id
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

resource "aws_security_group" "ecs" {
  name        = "serverless-ecs-${local.suffix}"
  vpc_id      = data.aws_vpc.example.id

  ingress {
    description = "allow all incoming traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   description = "Allow incoming traffic on port 80"
  # }

  egress {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "serverless-ssh-${local.suffix}"
  }
}
