resource "aws_ecs_cluster" "main" {
  name = "main"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    "AWS.SSM.AppManager.ECS.Cluster.ARN" = "arn:aws:ecs:ap-northeast-1:${local.aws_account_id}:cluster/main"
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "main"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.runners.arn
    managed_termination_protection = "DISABLED"
    managed_draining               = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
  }
}

resource "aws_ecs_task_definition" "app" {
  family = "app"
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "docker.io/nginx:1.27.0"
      cpu       = 10
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ]
    },
  ])
}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }
}
