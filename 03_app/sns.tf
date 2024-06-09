resource "aws_sns_topic" "consumer" {
  name = "consumer-${local.suffix}"
}

resource "aws_sns_topic_policy" "consumer" {
  arn    = aws_sns_topic.consumer.arn

  policy = jsonencode({
    Id      = "access"
    Statement = [
      {
        Action    = ["sns:Publish", "sns:GetTopicAttributes"]
        Effect    = "Allow"
        Principal = {
          AWS = "${aws_iam_user.bucket.arn}"
        }
        Resource = "*"
        Sid      = "allow-send"
      },
    ]
    Version = "2012-10-17"
  })
}

resource "aws_sns_topic_subscription" "consumer" {
  topic_arn = aws_sns_topic.consumer.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.heartbeat.arn
}
