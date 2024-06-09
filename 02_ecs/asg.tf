data "aws_ssm_parameter" "latest_optimized_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "private_tier1" {
  name_prefix   = "private-tier1-ecs-"
  ebs_optimized = true
  image_id      = data.aws_ssm_parameter.latest_optimized_ecs_ami.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.ecs.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_assume.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "private-tier1"
    }
  }

  user_data = filebase64("${path.module}/external/private_tier1.sh")
}

resource "aws_autoscaling_group" "private_tier1" {
  name = "private_tier1"

  vpc_zone_identifier = data.aws_subnets.private.ids

  max_size                  = 6
  min_size                  = 1
  desired_capacity          = 3
  health_check_type         = "EC2"
  health_check_grace_period = 0

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  termination_policies = [
    "AllocationStrategy",
    "OldestLaunchTemplate",
    "ClosestToNextInstanceHour",
    "Default"
  ]

  protect_from_scale_in = true
  max_instance_lifetime = 86400
  # force_delete              = true
  # wait_for_capacity_timeout = "1m"

  launch_template {
    name    = aws_launch_template.private_tier1.name
    version = aws_launch_template.private_tier1.latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity
    ]
  }

  tag {
    key                 = "Name"
    value               = "private-tier1-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "amazon-ecs-managed"
    value               = true
    propagate_at_launch = true
  }
}
