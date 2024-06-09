resource "aws_cloudwatch_log_group" "heartbeat" {
  name              = "/serverless/ecs/service/heartbeat"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "rds" {
  count             = length(local.db.log_group_names)
  name              = "/serverless/rds/instance/${local.db.log_group_names[count.index]}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}
