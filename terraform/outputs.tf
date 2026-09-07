output "instance_public_ip" {
  description = "IP publique fixe de l'instance EC2 (via Elastic IP)"
  value       = aws_eip.k3s_node.public_ip
}

output "ecr_repository_urls" {
  description = "URLs des repositories ECR créés, à utiliser dans GitHub Actions"
  value       = { for name, repo in aws_ecr_repository.microservices : name => repo.repository_url }
}

output "ssh_command" {
  description = "Commande pour se connecter en SSH à l'instance"
  value       = "ssh -i <chemin-vers-ta-clé>.pem ubuntu@${aws_eip.k3s_node.public_ip}"
}