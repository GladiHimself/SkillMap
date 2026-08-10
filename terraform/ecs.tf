# ── ECS Cluster ────────────────────────────────────────────────
# Logical grouping for all SkillMap ECS resources
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  # Container Insights — enhanced CloudWatch monitoring
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── CloudWatch Log Group for ECS ──────────────────────────────
# Where ECS container logs go
# Without this, logs are lost when container stops
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7  # keep logs 7 days — saves cost

  tags = {
    Project = var.project_name
  }
}

# ── ECS Task Definition ────────────────────────────────────────
# Blueprint for running the Spring Boot container
# Every deployment creates a new revision of this
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]  # serverless mode
  network_mode             = "awsvpc"     # required for Fargate
  cpu                      = 512          # 0.5 vCPU
  memory                   = 1024         # 1 GB RAM

  # IAM roles from Day 8
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # Container definition — what actually runs
  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-app"
      image = var.docker_image_url

      # Port mapping — container listens on 8080
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      # Environment variables passed to Spring Boot
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "aws"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.notifications.arn
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.resumes.bucket
        }
      ]

      # Secrets from Secrets Manager
      # ECS fetches these at runtime — never in plaintext
      secrets = [
        {
          name      = "SPRING_DATASOURCE_URL"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:url::"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]

      # Send logs to CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Health check — ECS restarts container if this fails
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O- http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 90
      }

      essential = true  # if this container stops, task stops
    }
  ])

  tags = {
    Project = var.project_name
  }
}

# ── Application Load Balancer ──────────────────────────────────
# Sits in public subnets — receives traffic from internet
# Forwards to ECS tasks in private subnets
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false        # public-facing
  load_balancer_type = "application"

  # ALB lives in public subnets
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  security_groups = [aws_security_group.alb.id]

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# ── Target Group ───────────────────────────────────────────────
# Tells ALB where to send traffic (which containers)
# ALB health checks containers via this target group
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # required for Fargate

  # Health check — ALB pings this endpoint
  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"  # expect HTTP 200
  }

  tags = {
    Project = var.project_name
  }
}

# ── ALB Listener ───────────────────────────────────────────────
# ALB listens on port 80 and forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── ECS Service ────────────────────────────────────────────────
# Keeps desired number of tasks running at all times
# Restarts tasks if they crash
# Registers tasks with the ALB target group
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1       # run 1 container
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 120

  # Network config — tasks run in private subnets
  # They can't be reached directly from internet
  # Only ALB can reach them
  network_configuration {
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false  # private subnet — no public IP
  }

  # Connect to ALB
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-app"
    container_port   = 8080
  }

  # Wait for ALB to be ready before creating service
  depends_on = [aws_lb_listener.http]

  tags = {
    Project = var.project_name
  }
}