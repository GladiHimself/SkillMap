# ── Lambda Alarms ────────────────────────────────────────────

# Fires if Lambda has any errors in a 5-minute window
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  alarm_description   = "Resume processor Lambda is throwing errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods   = 1
  metric_name          = "Errors"
  namespace            = "AWS/Lambda"
  period               = 300  # 5 minutes
  statistic            = "Sum"
  threshold            = 1

  dimensions = {
    FunctionName = aws_lambda_function.resume_processor.function_name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]
  ok_actions    = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

# Fires if Lambda is taking too long — Bedrock or RDS getting slow
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-slow"
  alarm_description   = "Resume processor Lambda is running slower than expected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "Duration"
  namespace            = "AWS/Lambda"
  period               = 300
  statistic            = "Average"
  threshold            = 60000  # 60 seconds in ms — well under our 120s timeout

  dimensions = {
    FunctionName = aws_lambda_function.resume_processor.function_name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

# Fires if messages end up in the Dead Letter Queue
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-has-messages"
  alarm_description   = "Resumes are failing processing 3+ times and landing in DLQ"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods   = 1
  metric_name          = "ApproximateNumberOfMessagesVisible"
  namespace            = "AWS/SQS"
  period               = 300
  statistic            = "Maximum"
  threshold            = 1

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

# ── RDS Alarms ──────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  alarm_description   = "RDS PostgreSQL CPU usage is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "CPUUtilization"
  namespace            = "AWS/RDS"
  period               = 300
  statistic            = "Average"
  threshold            = 80  # percent

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-rds-connection-limit"
  alarm_description   = "RDS is close to running out of available connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "DatabaseConnections"
  namespace            = "AWS/RDS"
  period               = 300
  statistic            = "Maximum"
  threshold            = 15  # db.t3.micro default max is ~66, alert well before

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

# ── ECS Alarms ──────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.project_name}-ecs-high-cpu"
  alarm_description   = "ECS Spring Boot task CPU usage is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "CPUUtilization"
  namespace            = "AWS/ECS"
  period               = 300
  statistic            = "Average"
  threshold            = 80

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${var.project_name}-ecs-high-memory"
  alarm_description   = "ECS Spring Boot task memory usage is high — risk of OOM kill"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "MemoryUtilization"
  namespace            = "AWS/ECS"
  period               = 300
  statistic            = "Average"
  threshold            = 85

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = { Project = var.project_name }
}

# ── CloudWatch Dashboard ────────────────────────────────────
# Single-page overview of the whole system's health
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Invocations & Errors"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.resume_processor.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.resume_processor.function_name]
          ]
          period  = 300
          stat    = "Sum"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Duration"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.resume_processor.function_name]
          ]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS — CPU & Connections"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.postgres.id],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.postgres.id]
          ]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS — CPU & Memory"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name]
          ]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "SQS — Queue Depth"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.resume_queue.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.dlq.name]
          ]
          period  = 300
          stat    = "Maximum"
          region  = var.aws_region
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Recent Lambda Errors"
          query   = "SOURCE '/aws/lambda/${var.project_name}-resume-processor' | fields @timestamp, message | filter level = \"ERROR\" | sort @timestamp desc | limit 20"
          region  = var.aws_region
          view    = "table"
        }
      }
    ]
  })
}