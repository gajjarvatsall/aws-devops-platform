# Database module

Creates an encrypted private MySQL RDS instance, a two-subnet DB subnet group,
and a Secrets Manager secret containing the standard RDS credential JSON shape.
The password and secret value are sensitive Terraform state, so use the remote
encrypted backend and restrict state readers.

