terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket  = "nukaloot-tfstate"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile = "nukaloot"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "nukaloot"
}
