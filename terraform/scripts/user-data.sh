#!/bin/bash
set -e

APP_DIR="/opt/nukaloot"

# --- Swap (2GB) ---
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

# --- Install Docker ---
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker ubuntu

# --- SSH key for GitHub (needed for infra repo) ---
mkdir -p /home/ubuntu/.ssh
cat <<'DEPLOY_KEY' > /home/ubuntu/.ssh/github_deploy
${github_deploy_key}
DEPLOY_KEY
chmod 600 /home/ubuntu/.ssh/github_deploy
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

cat <<'SSH_CONFIG' > /home/ubuntu/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile /home/ubuntu/.ssh/github_deploy
  IdentitiesOnly yes
  StrictHostKeyChecking no
SSH_CONFIG
chmod 600 /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config

# --- Clone infra repo only ---
mkdir -p "$APP_DIR"
chown ubuntu:ubuntu "$APP_DIR"

sudo -u ubuntu git clone git@github.com:padronjosef/nukaloot-infra.git "$APP_DIR/nukaloot-infra"

# --- Create .env for production ---
cat <<ENV > "$APP_DIR/nukaloot-infra/.env"
INTERNAL_API_URL=http://api:3000
WEB_APP_DOMAIN=${domain}
ENV
chown ubuntu:ubuntu "$APP_DIR/nukaloot-infra/.env"

# --- Generate nginx config ---
export DOMAIN="${domain}"
envsubst '$$DOMAIN' < "$APP_DIR/nukaloot-infra/nginx/nginx.conf.template" > "$APP_DIR/nukaloot-infra/nginx/nginx.conf"

# --- Start services (pull pre-built images from GHCR) ---
cd "$APP_DIR/nukaloot-infra"
sudo -u ubuntu docker compose -f docker-compose.prod.yml pull
sudo -u ubuntu docker compose -f docker-compose.prod.yml up -d

# --- Cron: weekly Docker cleanup ---
cat <<'CRON' | crontab -
0 3 * * 0 docker image prune -af && docker builder prune -af
CRON
