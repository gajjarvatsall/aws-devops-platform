# Compute module

Creates a public ALB with HTTP-to-HTTPS redirect, an HTTPS listener using an
operator-provided ACM certificate, and a private-subnet ASG using an
SSM-selected Amazon Linux 2023 ARM image. The default desired/minimum capacity
is zero so the ECR image can be pushed before application instances launch.

