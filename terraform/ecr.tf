resource "aws_ecr_repository" "microservices" {
  for_each = toset(var.microservices)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  # Permet à Terraform de supprimer le repo même s'il contient encore des images.
  # Pratique pour un projet de dev/apprentissage où on détruit/recrée souvent l'infra.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
  }
}

# Politique de cycle de vie : garde seulement les 10 dernières images
# pour éviter que le coût de stockage ECR grimpe indéfiniment.
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Garder seulement les 10 dernières images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}