# iam.tf

# --- Trust policy: WHO is allowed to assume this role ---
# This is the part people often mix up: this policy does NOT grant
# permissions to do anything in AWS. It only says "the Lambda service is
# allowed to assume this role's identity." Think of it as the lock on the
# door, separate from what's inside the room.
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.environment}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# --- Permission policy #1: basic logging ---
# This is an AWS-MANAGED policy (AWS maintains it, we just attach it) that
# grants permission to create CloudWatch Log Groups/Streams and write log
# events. Without this, your Lambda would run but you'd have zero visibility
# into what it's doing — no print()/console.log output anywhere.
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Permission policy #2: VPC networking ---
# A Lambda that needs to reach into a VPC (to talk to our private RDS
# instance) needs permission to create/manage Elastic Network Interfaces
# (ENIs) — the actual network adapters that get plugged into our subnets.
# This is a separate, also AWS-managed, policy.
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# NOTE on least privilege: we're using AWS-managed policies here for
# simplicity, which are broader than the absolute minimum this function
# needs. A production setup would typically write a CUSTOM policy granting
# only the exact actions required (e.g. only allow writing logs to THIS
# function's specific log group, not "any log group"). Worth mentioning as
# a deliberate simplification if asked about it.
