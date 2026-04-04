# Generate a random password (kept for Secrets Manager compatibility)
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "game-price/db-password"
  description             = "PostgreSQL password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "github_deploy_key" {
  name                    = "game-price/github-deploy-key"
  description             = "SSH private key for GitHub deploy access"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "github_deploy_key" {
  secret_id     = aws_secretsmanager_secret.github_deploy_key.id
  secret_string = tls_private_key.github_deploy.private_key_openssh
}
