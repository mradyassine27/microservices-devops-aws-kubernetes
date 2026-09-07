data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ecr_role" {
  name               = "${var.project_name}-ec2-ecr-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Politique gérée par AWS qui donne uniquement les droits de LECTURE sur ECR
# (pull d'images). Suffisant puisque c'est GitHub Actions qui push, pas l'EC2.
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_ecr_role.name
}