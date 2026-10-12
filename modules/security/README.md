# Security module

Creates tier-specific security groups and a narrowly scoped EC2 runtime role.
The ALB is the only public ingress point; application and database rules use
security-group references rather than internal CIDR allowlists.

