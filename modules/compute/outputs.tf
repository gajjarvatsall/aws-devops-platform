output "load_balancer_dns_name" { value = aws_lb.this.dns_name }
output "load_balancer_arn" { value = aws_lb.this.arn }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "autoscaling_group_name" { value = aws_autoscaling_group.app.name }
output "log_group_name" { value = aws_cloudwatch_log_group.app.name }

