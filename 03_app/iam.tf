resource "aws_iam_user" "bucket" {
  name = "bucket-${local.suffix}"
}

resource "aws_iam_access_key" "bucket" {
  user = aws_iam_user.bucket.name
}

resource "aws_iam_policy" "s3_read" {
  name        = "s3-read-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "${aws_s3_bucket.store.arn}/*",
      },
    ],
  })
}

resource "aws_iam_policy" "s3_write" {
  name        = "s3-write-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "${aws_s3_bucket.store.arn}/*",
      },
    ],
  })
}

resource "aws_iam_user_policy_attachment" "s3_read" {
  user       = aws_iam_user.bucket.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_user_policy_attachment" "s3_write" {
  user       = aws_iam_user.bucket.name
  policy_arn = aws_iam_policy.s3_write.arn
}

resource "aws_iam_role" "ec2_sqs_send_msg" {
  name               = "ec2-sqs-send-msg-${local.suffix}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ec2_sqs_send_message_policy" {
  name   = "ec2_sqs_send_message_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.heartbeat.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_sqs_send_message_policy" {
  policy_arn = aws_iam_policy.ec2_sqs_send_message_policy.arn
  role       = aws_iam_role.ec2_sqs_send_msg.name
}

resource "aws_iam_instance_profile" "sqs_send_msg" {
  name = "sqs-send-msg-${local.suffix}"
  role = aws_iam_role.ec2_sqs_send_msg.name
}

resource "aws_iam_policy" "receive_message_policy" {
  name   = "receive_message_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility"
      ],
        Resource = aws_sqs_queue.heartbeat.arn
      },
    ]
  })
}

resource "aws_iam_role" "heartbeat_ecs_task" {
  name               = "HeartbeatECSTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "heartbeat_ecs_task" {
  policy_arn = aws_iam_policy.receive_message_policy.arn
  role       = aws_iam_role.heartbeat_ecs_task.name
}

resource "aws_iam_policy" "rds_read_write" {
  name        = "RDSReadWrite"
  description = "Allows reading and writing to RDS PostgreSQL"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect",
        "rds-db:select",
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "rds:GenerateDBAuthToken"
      ],
      "Resource": "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:executeStatement",
        "rds-db:executeSql"
      ],
      "Resource": "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "wuser" {
  name = "wuser-${local.suffix}"
}

resource "aws_iam_user_policy_attachment" "rds_read_write" {
  user       = aws_iam_user.wuser.name
  policy_arn = aws_iam_policy.rds_read_write.arn
}


# resource "aws_iam_role" "ecs-tasks.amazonaws.com" {
#   name = "ecs-task-${local.suffix}"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = [
#             "ecs-tasks.amazonaws.com"
#           ]
#         }
#       },
#     ]
#   })
# }