# resource "aws_lb" "example" {
#   name                       = "example"
#   internal                   = false
#   load_balancer_type         = "application"
#   drop_invalid_header_fields = true

#   security_groups = [
#     aws_security_group.example_ecs.id
#   ]

#   subnets = data.aws_subnets.private.ids

#   # tags = {
#   #   Name  = "tf-alb-example"
#   #   Owner = "John Ajera"
#   # }
# }

resource "aws_ecs_task_definition" "heartbeat" {
  family        = "heartbeat"
  network_mode  = "bridge"
  task_role_arn = aws_iam_role.heartbeat_ecs_task.arn

  container_definitions = jsonencode([{
    name   = "heartbeat"
    image  = "public.ecr.aws/amazonlinux/amazonlinux:2023"
    cpu    = 256
    memory = 1024

    environment = [
      {
        name  = "AWS_REGION",
        value = "ap-southeast-2"
      },
      {
        name  = "DB_CONN_TIMEOUT",
        value = "5"
      },
      {
        name  = "DB_HOST",
        value = "db.rds.amazonaws.com"
      },
      {
        name  = "DB_MAX_IDLE_CONNS",
        value = "1"
      },
      {
        name  = "DB_MAX_OPEN_CONNS",
        value = "2"
      },
      {
        name  = "DB_NAME",
        value = "mydb"
      },
      {
        name  = "DB_PASSWD",
        value = "test"
      },
      {
        name  = "DB_SSLMODE",
        value = "disable"
      },
      {
        name  = "DB_USER",
        value = "user_w"
      },
      {
        name  = "SQS_QUEUE_URL",
        value = "sqs_url"
      }
    ]

    essential = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group" = "True"
        "awslogs-group"        = "/serverless/ecs/service/heartbeat"
        "awslogs-region"       = data.aws_region.current.name
      }
    }

    portMappings = [
      {
        containerPort = 8080
        hostPort      = 0
        protocol      = "tcp"
      }
    ]
  }])
}

resource "aws_ecs_service" "heartbeat" {
  name                               = "heartbeat"
  task_definition                    = aws_ecs_task_definition.heartbeat.arn
  cluster                            = data.aws_ecs_cluster.private_tier1.id
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags            = true
  enable_execute_command             = false

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  deployment_controller {
    type = "ECS"
  }

  health_check_grace_period_seconds = 0

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "REPLICA"

  lifecycle {
    ignore_changes = [
      capacity_provider_strategy,
      desired_count
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.heartbeat
  ]
}

# resource "aws_ecs_task_definition" "example" {
#   family       = "my-ecs-task"
#   network_mode = "awsvpc"
#   container_definitions = jsonencode([
#     {
#       name      = "my-container"
#       image     = "nginx:latest"
#       cpu       = 256
#       memory    = 512
#       essential = true
#       portMappings = [
#         {
#           containerPort = 80
#           hostPort      = 80
#           protocol      = "tcp"
#         }
#       ]
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = "/ecs/my-ecs-task"
#           "awslogs-region"        = data.aws_region.current.name
#           "awslogs-stream-prefix" = "ecs"
#         }
#       }
#       environment = [
#         { name = "ENV_VAR1", value = "value1" },
#         { name = "ENV_VAR2", value = "value2" },
#       ]
#     }
#   ])
# }

# resource "aws_ecs_service" "example" {
#   name            = "my-ecs-service"
#   cluster         = data.aws_ecs_cluster.private_tier1.id
#   task_definition = aws_ecs_task_definition.example.arn
#   desired_count   = 2 # Number of replicas

#   launch_type = "EC2" # Use EC2 launch type

#   # Additional configurations for EC2 launch type
#   network_configuration {
#     security_groups = [data.aws_security_group.ecs.id]
#     subnets         = data.aws_subnets.private.ids
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_appautoscaling_target" "service" {

#   max_capacity       = 5
#   min_capacity       = 1
#   resource_id        = "service/private-tier1/tf-staging-haz-db-consumer-haz-db-consumer-service" #join("/", compact(["service", local.cluster_name, local.task_name]))
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# resource "aws_appautoscaling_policy" "cpu" {
#   count = (!var.create_scheduled_task && var.autoscaling_cpu > 0) ? 1 : 0

#   name               = "cpu-auto-scaling"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.service[0].resource_id
#   scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
#   service_namespace  = aws_appautoscaling_target.service[0].service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#     scale_in_cooldown  = 300
#     scale_out_cooldown = 30
#     target_value       = var.autoscaling_cpu
#   }
# }

# resource "aws_appautoscaling_policy" "memory" {
#   count = (!var.create_scheduled_task && var.autoscaling_memory > 0) ? 1 : 0

#   name               = "memory-auto-scaling"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.service[0].resource_id
#   scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
#   service_namespace  = aws_appautoscaling_target.service[0].service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#     }
#     scale_in_cooldown  = 300
#     scale_out_cooldown = 30
#     target_value       = var.autoscaling_memory
#   }
# }


# resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
#   name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.dynamodb_table_read_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.dynamodb_table_read_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "DynamoDBReadCapacityUtilization"
#     }

#     target_value = 70
#   }
# }
