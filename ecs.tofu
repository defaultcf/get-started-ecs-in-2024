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
