#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: ./deploy.sh <tag>"
  exit 1
fi

TAG="$1"
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$STACK_DIR"

if [ ! -f .env ]; then
  echo ".env não encontrado"
  exit 1
fi

echo "==> Atualizando tags no .env"
php -r '
$envFile = ".env";
$tag = $argv[1];
$env = file_get_contents($envFile);
$env = preg_replace("/^APP_IMAGE_TAG=.*/m", "APP_IMAGE_TAG=$tag", $env);
$env = preg_replace("/^NGINX_IMAGE_TAG=.*/m", "NGINX_IMAGE_TAG=$tag", $env);
file_put_contents($envFile, $env);
' "$TAG"

echo "==> Pull das imagens"
docker compose pull

echo "==> Recriando containers"
docker compose up -d

echo "==> Aguardando app saudável"
for i in $(seq 1 40); do
  STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}' matrix-app-1 2>/dev/null || true)"
  if [ "$STATUS" = "healthy" ]; then
    echo "Deploy concluído com sucesso"
    exit 0
  fi

  echo "Tentativa $i/40 - status: $STATUS"
  sleep 3
done

echo "Falha no deploy"
docker compose logs app --tail=200 || true
exit 1
