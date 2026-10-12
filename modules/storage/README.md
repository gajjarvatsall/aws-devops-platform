# Storage module

Creates private encrypted application and ALB log buckets. The ALB log policy
uses the current service-principal delivery model and scopes writes to this
account's `AWSLogs/<account-id>/` prefix. Review AWS regional documentation
before deployment because logging requirements can evolve.
