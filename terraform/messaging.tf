# ── Dead Letter Queue ──────────────────────────────────────────
# Created FIRST because the main queue references it
# Holds messages that failed processing 3+ times
# Lets you debug failures without losing data
resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-resume-dlq"

  # How long a failed message stays in DLQ before expiring
  # 14 days gives you time to investigate and reprocess
  message_retention_seconds = 1209600  # 14 days in seconds

  tags = {
    Name        = "${var.project_name}-resume-dlq"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── Main SQS Queue ─────────────────────────────────────────────
# Receives events from S3 when a resume is uploaded
# Lambda reads from this queue and processes resumes
resource "aws_sqs_queue" "resume_queue" {
  name = "${var.project_name}-resume-queue"

  # How long a message is hidden from other consumers
  # while Lambda is processing it
  # If Lambda crashes mid-process, message becomes visible again after this
  visibility_timeout_seconds = 300  # 5 minutes — enough for AI processing

  # How long messages wait if nobody reads them
  message_retention_seconds = 86400  # 1 day

  # How long Lambda waits for messages before giving up
  # Long polling — more efficient than constantly checking
  receive_wait_time_seconds = 20

  # Connect the DLQ — after 3 failures, message goes here
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3  # try 3 times before sending to DLQ
  })

  tags = {
    Name        = "${var.project_name}-resume-queue"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── SQS Queue Policy ───────────────────────────────────────────
# By default SQS doesn't accept messages from anyone
# This policy explicitly allows S3 to send messages to our queue
# Without this, S3 events would be rejected by SQS
resource "aws_sqs_queue_policy" "resume_queue" {
  queue_url = aws_sqs_queue.resume_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ToSendMessages"
        Effect = "Allow"

        # Who is allowed to send messages
        Principal = {
          Service = "s3.amazonaws.com"  # only S3, not anyone else
        }

        # What they're allowed to do
        Action = "sqs:SendMessage"

        # Which queue they can send to
        Resource = aws_sqs_queue.resume_queue.arn

        # Extra condition — only our specific S3 bucket
        # Prevents other S3 buckets from sending to our queue
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.project_name}-resumes-${var.environment}"
          }
        }
      }
    ]
  })
}

# ── SNS Topic ──────────────────────────────────────────────────
# Lambda publishes here after processing a resume
# Anyone subscribed receives the notification
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-notifications"

  tags = {
    Name        = "${var.project_name}-notifications"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── SNS Email Subscription ─────────────────────────────────────
# Your email subscribes to the SNS topic
# AWS sends a confirmation email — you must click it to activate
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.notification_email)

  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = each.value
}