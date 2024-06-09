resource "aws_sqs_queue" "heartbeat" {
  name                      = "heartbeat-${local.suffix}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 0

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 4
  })

  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "dlq" {
  name                      = "heartbeat-dlq-${local.suffix}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "sqs_send_msg" {
  queue_url = aws_sqs_queue.heartbeat.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SQSPolicy"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "SQS:SendMessage"
        ]
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.consumer.arn
          }
        }
        Resource = aws_sqs_queue.heartbeat.arn
      },
    ]
  })
}
