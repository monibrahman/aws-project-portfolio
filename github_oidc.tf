# github_oidc.tf

# --- Register GitHub as a trusted OIDC identity provider ---
# This tells AWS "I trust tokens signed by GitHub's OIDC issuer." There's
# only ever ONE of these per AWS account for GitHub (not one per repo).
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # This thumbprint is GitHub's OIDC certificate thumbprint. AWS actually
  # no longer strictly validates this value (it fetches the cert chain
  # itself), but the provider still requires the field to be set.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- Trust policy: which GitHub repo/branch is allowed to assume this role ---
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # This condition is the actual security boundary: without it, ANY
    # GitHub repo anywhere could assume this role, because the OIDC
    # provider itself just proves "this token really came from GitHub" —
    # it says nothing about WHICH repo. This line is what scopes it down
    # to specifically your repo, and only pushes to main (not PRs from
    # forks, not other branches).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.environment}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# --- Permissions: what this role can actually DO in AWS ---
# For a portfolio project, AdministratorAccess is the pragmatic choice since
# Terraform needs broad permissions to manage many resource types. In a real
# team setting, you'd scope this to exactly the services this project uses
# (ec2, rds, lambda, apigateway, iam:PassRole, s3, dynamodb) — worth
# mentioning as a deliberate simplification, same as the local admin user
# from earlier.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC"
  value       = aws_iam_role.github_actions.arn
}
