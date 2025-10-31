# --------------------------
# APPLICATION LOAD BALANCER
# --------------------------
resource "aws_lb" "soar_alb" {
  name               = "soar-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # Gebruik de 2 public subnets voor de ALB
  subnets = [
    aws_subnet.public_lb_subnet_a.id,
    aws_subnet.public_lb_subnet_b.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "soar-alb"
  }
}

# --------------------------
# TARGET GROUP
# --------------------------
resource "aws_lb_target_group" "soar_tg" {
  name     = "soar-tg"
  port     = var.http_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "soar-tg"
  }
}

# --------------------------
# HTTP LISTENER
# --------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.soar_alb.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.soar_tg.arn
  }
}

# --------------------------
# OUTPUTS
# --------------------------
output "alb_dns_name" {
  value = aws_lb.soar_alb.dns_name
}
