#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: ./deploy.sh <tag>"
  exit 1
fi

TAG="$1"
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$STACK_DIR"

echo "==> Verificando .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Arquivo .env criado a partir de .env.example"
  echo "Edite o .env antes de continuar."
  exit 1
fi

echo "==> Garantindo upstream nginx"
mkdir -p nginx
if [ ! -f nginx/upstream.conf ]; then
  echo "server app:9000;" > nginx/upstream.conf
fi

echo "==> Validando Docker"
docker info >/dev/null

echo "==> Subindo infraestrutura e aplicação"
docker compose pull
docker compose up -d

echo "==> Aguardando app"
for i in $(seq 1 40); do
  STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}' matrix-app-1 2>/dev/null || true)"
  if [ "$STATUS" = "healthy" ]; then
    echo "App saudável"
    exit 0
  fi

  echo "Tentativa $i/40 - status: $STATUS"
  sleep 3
done

echo "App não ficou saudável a tempo"
docker compose logs app --tail=200 || true
exit 1
