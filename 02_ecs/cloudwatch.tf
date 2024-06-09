resource "aws_cloudwatch_log_group" "private_tier1" {
  name              = "/serverless/ecs/cluster/private-tier1"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "cwagent" {
  name              = "/serverless/ecs/service/cwagent"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}
