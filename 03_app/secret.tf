resource "aws_secretsmanager_secret" "serverless" {
  name                    = "serverless-${local.suffix}"
  recovery_window_in_days = 0
}

resource "random_password" "rds_dbadmin" {
  length           = 16
  special          = true
  override_special = "_!#%&*()-<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret_version" "rds_dbadmin" {
  secret_id     = aws_secretsmanager_secret.serverless.id
  secret_string = "{\"dbadmin\": \"${random_password.rds_dbadmin.result}\"}"
}

resource "random_password" "rds_wuser" {
  length           = 16
  special          = true
  override_special = "_!#%&*()-<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret_version" "rds_wuser" {
  secret_id     = aws_secretsmanager_secret.serverless.id
  secret_string = "{\"wuser\": \"${random_password.rds_wuser.result}\"}"
}

resource "random_password" "rds_ruser" {
  length           = 16
  special          = true
  override_special = "_!#%&*()-<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret_version" "rds_ruser" {
  secret_id     = aws_secretsmanager_secret.serverless.id
  secret_string = "{\"ruser\": \"${random_password.rds_ruser.result}\"}"
}
