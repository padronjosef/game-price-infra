output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (update Cloudflare A record with this)"
  value       = aws_instance.app.public_ip
}

output "domain" {
  description = "App domain"
  value       = var.domain
}

output "ssh_command" {
  description = "SSH into the EC2 instance"
  value       = "ssh ubuntu@${aws_instance.app.public_ip}"
}

output "github_deploy_public_key" {
  description = "Add this as a deploy key (read-only) to each GitHub repo"
  value       = tls_private_key.github_deploy.public_key_openssh
}
