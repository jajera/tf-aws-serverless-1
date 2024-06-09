locals {
  suffix = data.terraform_remote_state.state1.outputs.suffix
  vpc_id = data.terraform_remote_state.state1.outputs.vpc_id
}
