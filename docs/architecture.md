# Architecture

The environment roots call the same reusable modules. The network module
creates a DNS-enabled VPC with two public, two private application, and two
private database subnets across provider-selected Availability Zones. The ALB
is the only public ingress point; HTTP redirects to HTTPS and instances are
reachable only from the ALB security group. RDS is private and reachable only
from the application security group.

The [Mermaid source](architecture.mmd) reflects the deployed shape. ECR is
created before the ASG is scaled above zero. Secrets Manager supplies the
credential JSON to the application through the EC2 instance role. CloudWatch
receives bootstrap/application logs, while S3 stores application objects and
ALB access logs.

