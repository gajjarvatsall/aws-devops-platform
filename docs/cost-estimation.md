# Cost considerations

The largest variable costs are NAT Gateway hourly/data processing, ALB hours
and LCU usage, EC2 instance hours, RDS class/storage/backup, CloudWatch log
ingestion and retention, ECR storage, S3 storage/requests, and public IPv4
addresses. A single NAT Gateway is the development default; one per AZ improves
availability but costs more. Dev defaults to a small single-AZ RDS and zero
instances until an image exists. Production settings increase capacity,
retention, and Multi-AZ resilience.

Exact prices depend on region, traffic, storage, and purchase model; use the
AWS Pricing Calculator with those inputs. Delete non-production resources and
expire logs/images deliberately, while retaining required backups and state.

