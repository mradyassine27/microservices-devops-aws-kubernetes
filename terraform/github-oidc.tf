# ─── Fournisseur d'identité OIDC pour GitHub Actions ───
# Permet à AWS de faire confiance aux tokens signés par GitHub,
# sans jamais stocker de clé d'accès AWS dans les secrets GitHub.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # Thumbprint standard pour token.actions.githubusercontent.com
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
}

# ─── Rôle IAM que GitHub Actions va assumer ───

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restreint l'accès à TON repo GitHub uniquement.
    # Remplace <TON_USERNAME_GITHUB>/<TON_REPO> avant utilisation.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:mrad-yassine/microservices-devops-aws-kubernetes:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_ecr" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Permission de push/pull vers ECR (plus large que ReadOnly, car GitHub doit pousser)
resource "aws_iam_role_policy_attachment" "github_actions_ecr_power_user" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

output "github_actions_role_arn" {
  description = "ARN du rôle à utiliser dans le workflow GitHub Actions"
  value       = aws_iam_role.github_actions_ecr.arn
}
