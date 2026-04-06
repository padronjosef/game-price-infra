variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain" {
  description = "Domain name (e.g. nukaloot.com)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "alert_email" {
  description = "Email for health check alerts"
  type        = string
  sensitive   = true
}
