locals { tags = merge(var.tags, { ManagedBy = "Terraform", Component = "alb" }) }

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
  access_logs {
    bucket  = var.logs_bucket_id
    prefix  = "alb"
    enabled = true
  }
  tags = merge(local.tags, { Name = "${var.name}-alb" })
}
resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = local.tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      target_group { arn = aws_lb_target_group.app.arn }
    }
  }
}
