variable "aws_region" {
  description = "Région AWS où déployer les ressources"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Nom du projet, utilisé comme préfixe pour toutes les ressources"
  type        = string
  default     = "microservices-demo"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_name" {
  description = "Nom de la key pair EC2 existante à utiliser pour le SSH"
  type        = string
}

variable "my_ip" {
  description = "Ton IP publique (format CIDR, ex: 1.2.3.4/32) autorisée pour le SSH"
  type        = string
}

variable "vpc_cidr" {
  description = "Plage CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Plage CIDR du subnet public"
  type        = string
  default     = "10.0.1.0/24"
}

variable "microservices" {
  description = "Liste des microservices pour lesquels créer un repo ECR"
  type        = list(string)
  default = [
    "frontend",
    "cartservice",
    "productcatalogservice",
    "checkoutservice",
    "currencyservice",
    "shippingservice",
    "paymentservice",
    "telegrambot",
  ]
}