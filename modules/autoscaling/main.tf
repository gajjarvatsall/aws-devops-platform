data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals { tags = merge(var.tags, { ManagedBy = "Terraform", Component = "autoscaling" }) }

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  iam_instance_profile { name = var.instance_profile_name }
  vpc_security_group_ids = [var.security_group_id]
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    ecr_repository_url   = var.ecr_repository_url
    ecr_registry         = split("/", var.ecr_repository_url)[0]
    app_port             = var.app_port
    image_parameter_name = var.image_parameter_name
    environment          = var.environment
    region               = var.region
    database_secret_arn  = var.database_secret_arn
    asg_name             = "${var.name}-app-asg"
    target_group_arn     = var.target_group_arn
    rds_identifier       = var.rds_identifier
    ecr_repository_name  = var.ecr_repository_name
    log_group            = var.log_group_name
  }))
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.name}-app" })
  }
}

resource "aws_autoscaling_group" "app" {
  name             = "${var.name}-app-asg"
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  lifecycle { ignore_changes = [desired_capacity, min_size] }
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 180
  target_group_arns         = [var.target_group_arn]
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      skip_matching          = false
    }
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
