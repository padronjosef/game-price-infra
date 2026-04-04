#!/bin/bash
set -e

APP_DIR="/opt/game-price-finder"
SERVICE="$1"
ENV_FILE="$APP_DIR/game-price-infra/.env"

if [ -z "$SERVICE" ]; then
  echo "Usage: deploy.sh <api|web|infra|all>"
  exit 1
fi

# Read DOMAIN from .env file (single source of truth)
if [ -f "$ENV_FILE" ]; then
  export DOMAIN=$(grep -oP '(?<=WEB_APP_DOMAIN=).+' "$ENV_FILE" || echo "")
fi

regenerate_nginx() {
  if [ -z "$DOMAIN" ]; then
    echo "ERROR: DOMAIN is empty — refusing to regenerate nginx config"
    exit 1
  fi
  envsubst '$$DOMAIN' < "$APP_DIR/game-price-infra/nginx/nginx.conf.template" > "$APP_DIR/game-price-infra/nginx/nginx.conf"
  echo "Nginx config regenerated for $DOMAIN"
}

cd "$APP_DIR/game-price-infra"

case "$SERVICE" in
  api)
    echo "Deploying API..."
    docker compose -f docker-compose.prod.yml pull api
    docker compose -f docker-compose.prod.yml up -d api
    ;;
  web)
    echo "Deploying Web..."
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull web
    docker compose -f docker-compose.prod.yml up -d web
    docker compose -f docker-compose.prod.yml restart nginx
    ;;
  infra)
    echo "Deploying Infra..."
    git checkout -- . && git pull origin main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull
    docker compose -f docker-compose.prod.yml up -d
    ;;
  all)
    echo "Deploying all..."
    git checkout -- . && git pull origin main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull
    docker compose -f docker-compose.prod.yml up -d
    ;;
  *)
    echo "Unknown service: $SERVICE"
    exit 1
    ;;
esac

# Clean up old images
docker image prune -f

echo "Deploy complete."
