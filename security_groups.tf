# security_groups.tf

resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-rds-"
  description = "Allow Postgres access from within the VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from within the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # Restricting the source to our own VPC's CIDR, NOT 0.0.0.0/0. This is
    # the single most important line in this file — it's what keeps the
    # database unreachable from the public internet even though we're about
    # to give it an endpoint/hostname.
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-rds-sg"
  }

  # Security groups referenced by other resources (like RDS) sometimes need
  # to be replaced rather than updated in place. This tells Terraform to
  # build the replacement BEFORE destroying the old one, avoiding a brief
  # window with no security group at all.
  lifecycle {
    create_before_destroy = true
  }
}
