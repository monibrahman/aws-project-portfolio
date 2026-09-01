# lambda.tf

# --- Zip the Lambda code ---
# `archive_file` is a Terraform "data source" (it reads/computes something,
# rather than creating a real AWS resource) that zips our source folder into
# a deployable package. This runs locally on your machine, cross-platform,
# no separate zip tool needed.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda_src.zip"
}

# --- Security group for the Lambda's network interfaces ---
# Outbound-only: Lambda initiates connections (to RDS, to the internet via
# NAT if needed) but nothing ever initiates an inbound connection TO a
# Lambda function directly — API Gateway invokes it through the Lambda
# service API, not over the VPC network, so no inbound rule is needed here.
resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-lambda-"
  description = "Lambda function network access"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-lambda-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Explicit CloudWatch Log Group ---
# If you don't create this yourself, Lambda auto-creates one on first
# invocation with indefinite retention (logs kept forever, silently costing
# you storage). Creating it explicitly lets us set a retention period.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-api"
  retention_in_days = 7
}

# --- The Lambda function itself ---
resource "aws_lambda_function" "api" {
  function_name = "${var.environment}-api"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler" # filename.function_name
  runtime       = "python3.12"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  # source_code_hash lets Terraform detect when the zip contents actually
  # changed, so it knows to redeploy — without this, editing your Lambda
  # code wouldn't trigger a new deployment on the next apply.

  timeout     = 10 # seconds
  memory_size = 128

  # Placing the function's network interfaces in our PRIVATE subnets is what
  # gives it a route to RDS. It's still fully invokable from the internet
  # via API Gateway — VPC placement controls its OUTBOUND network reach, not
  # whether it can be triggered.
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
      DB_HOST     = aws_db_instance.main.address
      DB_NAME     = aws_db_instance.main.db_name
      DB_USER     = aws_db_instance.main.username
      # Deliberately NOT passing the DB password as a plaintext env var here
      # — that's a common but sloppy real-world pattern. We'll wire this up
      # properly (Secrets Manager) once we actually need the Lambda to query
      # the database. For now it's unused by our health-check handler.
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = {
    Name = "${var.environment}-api-lambda"
  }
}
