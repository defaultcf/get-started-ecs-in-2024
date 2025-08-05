resource "aws_lb" "app" {
  name               = "app"
  load_balancer_type = "application"
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  security_groups    = []
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group" "app" {
  vpc_id   = aws_vpc.main.id
  name     = "app"
  port     = 80
  protocol = "HTTP"
}

# Security Group

resource "aws_security_group" "alb" {
  name   = "alb"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "-1"
  source_security_group_id = aws_security_group.runner.id
}
