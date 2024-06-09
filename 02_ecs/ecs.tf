resource "aws_ecs_cluster" "private_tier1" {
  name = "private-tier1"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.private_tier1.name
      }
    }
  }
}

resource "aws_ecs_capacity_provider" "private_tier1" {
  name = "private-tier1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.private_tier1.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name = "private-tier1"
  }
}

resource "aws_ecs_cluster_capacity_providers" "private_tier1" {
  cluster_name = aws_ecs_cluster.private_tier1.name

  capacity_providers = [
    aws_ecs_capacity_provider.private_tier1.name
  ]

  default_capacity_provider_strategy {
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.private_tier1.name
  }
}

resource "aws_ssm_parameter" "cwagent" {
  name        = "cwagent-config"
  description = "CloudWatch agent config for example cluster instances"
  type        = "String"
  value = jsonencode(
    {
      "agent" : {
        "metrics_collection_interval" : 60
      },
      "logs" : {
        "metrics_collected" : {
          "ecs" : {
            "metrics_collection_interval" : 30
          }
        },
        "logs_collected" : {
          "files" : {
            "collect_list" : [
              {
                "file_path" : "/var/log/ecs/ecs-agent.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-agent",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/ecs-init.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-init",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/audit.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-audit",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/messages",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/messages",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/secure",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/secure",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/auth.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/auth",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/amazon/efs/mount.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/mount.log",
                "timezone" : "UTC"
              }
            ]
          }
        },
        "force_flush_interval" : 15
      }
    }
  )
}

resource "aws_ecs_task_definition" "cwagent" {
  cpu                      = 128
  memory                   = 256
  family                   = "cwagent"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.cwagent_task.arn
  execution_role_arn       = aws_iam_role.cwagent_execution.arn

  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "dev"
    host_path = "/dev"
  }

  volume {
    name      = "host_logs"
    host_path = "/var/log"
  }

  volume {
    name      = "al1_cgroup"
    host_path = "/cgroup"
  }

  volume {
    name      = "al2_cgroup"
    host_path = "/sys/fs/cgroup"
  }

  container_definitions = jsonencode([{
    name   = "cloudwatch-agent"
    image  = "amazon/cloudwatch-agent:latest"
    cpu    = 128
    memory = 256

    mountPoints = [
      {
        readOnly      = true,
        containerPath = "/rootfs/proc",
        sourceVolume  = "proc",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/dev",
        sourceVolume  = "dev",
      },
      {
        readOnly      = true,
        containerPath = "/sys/fs/cgroup",
        sourceVolume  = "al2_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/cgroup",
        sourceVolume  = "al1_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/sys/fs/cgroup",
        sourceVolume  = "al2_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/cgroup",
        sourceVolume  = "al1_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/var/log",
        sourceVolume  = "host_logs",
      },
    ],

    secrets = [
      {
        name      = "CW_CONFIG_CONTENT",
        valueFrom = "cwagent-config",
      },
    ],

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-create-group"  = "True",
        "awslogs-group"         = "/serverless/ecs/service/cwagent",
        "awslogs-region"        = "${data.aws_region.current.name}",
        "awslogs-stream-prefix" = "daemon",
      }
    },
  }])
}

resource "aws_ecs_service" "cwagent" {
  name                = "cwagent"
  cluster             = aws_ecs_cluster.private_tier1.id
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "DAEMON"
  task_definition     = aws_ecs_task_definition.cwagent.arn

  enable_ecs_managed_tags = true

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_cloudwatch_log_group.cwagent
  ]
}
