terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "microservices-demo-tfstate-yassine"
    key     = "microservices-demo/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}


provider "aws" {
  region = var.aws_region
}