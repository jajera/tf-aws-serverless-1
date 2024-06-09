resource "aws_db_subnet_group" "example" {
  name = "${local.db.name}-${local.suffix}"

  subnet_ids = data.aws_subnets.database.ids
}

resource "aws_db_parameter_group" "serverless" {
  name_prefix = "${local.db.name}-"
  family      = "postgres16"
  description = "serverless parameter group"

  parameter {
    apply_method = "immediate"
    name         = "autovacuum"
    value        = "1"
  }

  parameter {
    apply_method = "immediate"
    name         = "client_encoding"
    value        = "utf8"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage       = 5
  storage_type            = "gp2"
  db_name                 = local.db.name
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.t3.micro"
  identifier              = "${local.db.name}-${local.suffix}"
  username                = "dbadmin"
  password                = random_password.rds_dbadmin.result
  parameter_group_name    = aws_db_parameter_group.serverless.name
  db_subnet_group_name    = aws_db_subnet_group.example.name
  vpc_security_group_ids  = [aws_security_group.psql.id]
  multi_az                = true
  backup_retention_period = 1
  backup_window           = "03:00-06:00"
  maintenance_window      = "mon:00:00-mon:03:00"
  deletion_protection     = false
  apply_immediately       = false
  skip_final_snapshot     = true
  copy_tags_to_snapshot   = false
  max_allocated_storage   = 5
  port                    = 5432

  depends_on = [
    aws_cloudwatch_log_group.rds,
    aws_db_parameter_group.serverless
  ]
}

resource "aws_db_instance" "read" {
  instance_class         = "db.t3.micro"
  identifier             = "${local.db.name}-${local.suffix}-read"
  replicate_source_db    = aws_db_instance.main.identifier
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16"
  vpc_security_group_ids = [aws_security_group.psql.id]
  multi_az               = true
  apply_immediately      = false
  copy_tags_to_snapshot  = false
  max_allocated_storage  = 5
  parameter_group_name   = aws_db_parameter_group.serverless.name
  port                   = 5432
  skip_final_snapshot    = true
}
