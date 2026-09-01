# rds.tf

# --- Auto-generated database password ---
# `random_password` is a Terraform resource that generates a secure random
# string and stores it in state. This means the password never has to be
# typed by a human, pasted anywhere, or committed to git. We'll retrieve it
# via `terraform output` when we actually need it (e.g. to connect locally).
resource "random_password" "db" {
  length  = 24
  special = false
  # Excluding special characters purely to avoid connection-string escaping
  # headaches later — 24 random alphanumeric characters is still extremely
  # strong.
}

# --- DB subnet group ---
# RDS needs to know WHICH subnets it's allowed to place database instances
# in. We give it our two private subnets — this is what guarantees the
# database itself never ends up in a public subnet, regardless of other
# settings.
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

# --- The RDS instance itself ---
resource "aws_db_instance" "main" {
  identifier = "${var.environment}-db"

  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20 # GB — the AWS Free Tier covers up to 20GB
  storage_type           = "gp3"
  storage_encrypted     = true

  db_name  = "portfolio"
  username = "app_admin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # THE key line for security: this database gets NO public IP / public
  # endpoint. Combined with living in a private subnet and the security
  # group restricting inbound to VPC-only traffic, this is defense in depth
  # — three separate layers all have to be bypassed, not just one.
  publicly_accessible = false

  multi_az = false
  # Multi-AZ automatically maintains a live standby replica in a second AZ
  # for automatic failover — the production-grade choice, but it roughly
  # doubles RDS cost. Another deliberate cost-vs-availability trade-off,
  # same idea as the single NAT Gateway earlier.

  backup_retention_period = 1 # days; production would typically use 7-35
  skip_final_snapshot     = true
  # skip_final_snapshot=true means when we `terraform destroy` later, RDS
  # won't create a final backup snapshot before deleting. Fine for a
  # portfolio project we intend to tear down; in production you'd almost
  # always want a final snapshot as a safety net.

  deletion_protection = false
  # Also fine for a learning project; production databases should usually
  # set this to true so a stray `terraform destroy` can't nuke real data
  # without an extra manual step.

  tags = {
    Name = "${var.environment}-db"
  }
}
