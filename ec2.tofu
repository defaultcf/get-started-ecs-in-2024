resource "aws_iam_role" "ecs_instance" {
  name = "ecs-instance"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy" "ecs_ec2_role" {
  name = "AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = data.aws_iam_policy.ecs_ec2_role.arn
}

data "aws_iam_policy" "ssm_managed_instance_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = data.aws_iam_policy.ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "main" {
  name = "main"
  role = aws_iam_role.ecs_instance.id
}

resource "aws_launch_template" "runner" {
  for_each = {
    "arm64" = {
      instance_type = "t4g.medium"
      # With AMI name mentioned in the comments
      # amiFilter=[{"Name":"owner-alias","Values":["amazon"]},{"Name":"name","Values":["al2023-ami-ecs-hvm-*-arm64"]}]
      # currentImageName=al2023-ami-ecs-hvm-2023.0.20240807-kernel-6.1-arm64
      image_id = "ami-043df6ccca357ecdf"
    }
    "x86_64" = {
      instance_type = "t2.medium"
      # With AMI name mentioned in the comments
      # amiFilter=[{"Name":"owner-alias","Values":["amazon"]},{"Name":"name","Values":["al2023-ami-ecs-hvm-*-x86_64"]}]
      # currentImageName=al2023-ami-ecs-hvm-2023.0.20240807-kernel-6.1-x86_64
      image_id = "ami-0502f5e2c7ed3ca69"
    }
  }

  name                   = "runner-${each.key}"
  instance_type          = each.value.instance_type
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data = base64encode(
    <<EOF
#!/bin/bash
echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
EOF
  )

  image_id = each.value.image_id

  iam_instance_profile {
    name = aws_iam_instance_profile.main.id
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "runner-${each.key}"
    }
  }
}

resource "aws_autoscaling_group" "runners" {
  name                  = "runners"
  vpc_zone_identifier   = [for subnet in aws_subnet.private : subnet.id]
  max_size              = 6
  min_size              = 2
  desired_capacity      = 2
  desired_capacity_type = "units"

  capacity_rebalance        = true
  health_check_grace_period = 60

  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 200
  }

  enabled_metrics = [
    "GroupAndWarmPoolDesiredCapacity",
    "GroupAndWarmPoolTotalCapacity",
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
    "WarmPoolDesiredCapacity",
    "WarmPoolMinSize",
    "WarmPoolPendingCapacity",
    "WarmPoolTerminatingCapacity",
    "WarmPoolTotalCapacity",
    "WarmPoolWarmedCapacity",
  ]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.runner["arm64"].id
        version            = aws_launch_template.runner["arm64"].latest_version
      }

      override {
        instance_type     = aws_launch_template.runner["arm64"].instance_type
        weighted_capacity = "3"
      }

      override {
        instance_type     = aws_launch_template.runner["x86_64"].instance_type
        weighted_capacity = "2"
        launch_template_specification {
          launch_template_id = aws_launch_template.runner["x86_64"].id
          version            = aws_launch_template.runner["x86_64"].latest_version
        }
      }
    }

    instances_distribution {
      on_demand_percentage_above_base_capacity = "0"
      spot_allocation_strategy                 = "price-capacity-optimized"
      spot_instance_pools                      = 0
    }
  }

  # インスタンス更新を走らせる
  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,
    ]
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}


# Security Group

resource "aws_security_group" "runner" {
  name   = "runner"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "runner"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "runner_ingress_alb" {
  security_group_id        = aws_security_group.runner.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "for_runner_egress" {
  security_group_id = aws_security_group.runner.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
