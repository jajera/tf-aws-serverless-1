locals {
  suffix      = data.terraform_remote_state.state1.outputs.suffix
  vpc_id      = data.terraform_remote_state.state1.outputs.vpc_id
  vpc_network = data.terraform_remote_state.state1.outputs.vpc_network
  db = {
    log_group_names = ["postgresql", "upgrade"]
    name            = "serverless"
  }
  current = {
    user_id = split("/", data.aws_caller_identity.current.arn)[1]
  }
}
