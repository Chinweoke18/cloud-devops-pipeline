resource "null_resource" "debug_path" {
  provisioner "local-exec" {
    command = "echo ${path.module}/scripts/service.json.tpl"
  }
}

resource "aws_cloudwatch_log_group" "cb_log_group" {
  name              =  "/ecs/${var.microservice_name}"
  retention_in_days = 30

  tags = {
    Name = "cloud-devops-log"
  }
}

resource "aws_ecr_repository" "ecs" {
  name                 = "${var.microservice_name}-ecr-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "external" "tags_of_most_recently_pushed_image" {
  program = [
    "aws", "ecr", "describe-images",
    "--repository-name", "${aws_ecr_repository.ecs.name}",
    "--query", "{\"tags\": to_string(sort_by(imageDetails, &imagePushedAt)[-1].imageTags)}",
    "--region", "${var.region}"
  ]
}

output "repository_uri" {
  value = aws_ecr_repository.ecs.repository_url
}

resource "aws_alb_target_group" "app" {
  name        = "${var.microservice_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }
}

# resource "aws_lb_listener_rule" "static" {
#   listener_arn = var.listener_arn
#   # priority     = 100

#   action {
#     type             = "forward"
#     target_group_arn = aws_alb_target_group.app.arn
#   }

#   condition {
#     path_pattern {
#       values = var.pattern_value
#     }
#   }
# }

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "alb" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.app_port #"80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}



# ECS task security group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.microservice_name}-tsk-sg"
  description = "allow inbound access from the ALB only"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [var.lb_security_groups]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# script
data "template_file" "cb_app" {
  template = file(var.script_path) #file("${path.module}/../scripts/service.json.tpl")

  vars = {
    microservice_name = var.microservice_name
    image_tag      = (jsondecode(data.external.tags_of_most_recently_pushed_image.result.tags) == null ? "latest" : jsondecode(data.external.tags_of_most_recently_pushed_image.result.tags)[0])
    app_image      = aws_ecr_repository.ecs.repository_url
    # ecr_repo_url   = aws_ecr_repository.ecs.repository_url
    app_port       = var.app_port
    app_name       = var.microservice_name
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.region
  }
}


#ECS task definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.microservice_name}-tsk"
  execution_role_arn       = var.execution_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.cb_app.rendered
}


#ECS service
resource "aws_ecs_service" "main" {
  name            = "${var.microservice_name}"
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.subnets
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   =  "${var.microservice_name}"
    container_port   = var.app_port
  }

  depends_on = [aws_cloudwatch_log_group.cb_log_group]
}
#aws_alb_listener.alb, 


# Microservice autoscaling
resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster}/${var.microservice_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 6

  depends_on = [aws_ecs_service.main]
}

# Automatically scale capacity up by one
resource "aws_appautoscaling_policy" "up" {
  name               = "${var.microservice_name}-upscale"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster}/${var.microservice_name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_ecs_service.main, aws_appautoscaling_target.target]
}

# Automatically scale capacity down by one
resource "aws_appautoscaling_policy" "down" {
  name               = "${var.microservice_name}-downscale"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster}/${var.microservice_name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [aws_ecs_service.main, aws_appautoscaling_target.target]
}

# CloudWatch alarm that triggers the autoscaling up policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.microservice_name}-cpu-HIGH"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "85"

  dimensions = {
    ClusterName = var.ecs_cluster
    ServiceName = var.microservice_name
  }

  alarm_actions = [aws_appautoscaling_policy.up.arn]
}

# CloudWatch alarm that triggers the autoscaling down policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_low" {
  alarm_name          = "${var.microservice_name}-cpu-LOW"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    ClusterName = var.ecs_cluster
    ServiceName = var.microservice_name
  }

  alarm_actions = [aws_appautoscaling_policy.down.arn]
}

terraform {
  backend "s3" {}
}