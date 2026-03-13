#!/bin/bash
set -e

echo "================================="
echo " PTERODACTYL PANEL AUTO INSTALL"
echo "================================="

ADMIN_EMAIL="admin@panel.local"
ADMIN_USER="admin"
ADMIN_PASS="Admin123!"
FIRST_NAME="Admin"
LAST_NAME="Panel"

ROOT_DB_PASS="rootpass"
PANEL_DB_PASS="panelpass"

WORKDIR="ptero"
mkdir -p $WORKDIR/srv/{database,var,logs}
cd $WORKDIR

echo "[1/8] Membuat docker-compose.yml"

cat > docker-compose.yml <<EOF
version: "3.8"

services:
  database:
    image: mariadb:10.5
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $ROOT_DB_PASS
      MYSQL_DATABASE: panel
      MYSQL_USER: pterodactyl
      MYSQL_PASSWORD: $PANEL_DB_PASS
    volumes:
      - "./srv/database:/var/lib/mysql"

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    depends_on:
      - database
      - cache
    ports:
      - "8080:80"
    volumes:
      - "./srv/var:/app/var/"
      - "./srv/logs:/app/storage/logs"
    environment:
      APP_URL: "http://localhost:8080"
      APP_ENV: "production"
      APP_DEBUG: "false"
      APP_TIMEZONE: "UTC"
      DB_HOST: "database"
      DB_PORT: "3306"
      DB_DATABASE: "panel"
      DB_USERNAME: "pterodactyl"
      DB_PASSWORD: "$PANEL_DB_PASS"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
EOF

echo "[2/8] Menjalankan container"
docker compose up -d

echo "[3/8] Menunggu database start..."
sleep 25

echo "[4/8] Migrasi database"
docker compose run --rm panel php artisan migrate --seed --force

echo "[5/8] Generate APP_KEY"
docker compose run --rm panel php artisan key:generate --force

echo "[6/8] Disable reCAPTCHA"
docker compose exec panel sed -i 's/RECAPTCHA_ENABLED=.*/RECAPTCHA_ENABLED=false/g' /app/.env || true

echo "[7/8] Membuat admin otomatis"
docker compose run --rm panel php artisan p:user:make \
 --email=$ADMIN_EMAIL \
 --username=$ADMIN_USER \
 --name-first=$FIRST_NAME \
 --name-last=$LAST_NAME \
 --password=$ADMIN_PASS \
 --admin=1

echo "[8/8] Restart panel"
docker compose restart panel

echo ""
echo "================================="
echo " INSTALL SELESAI"
echo "================================="
echo "Panel URL  : http://localhost:8080"
echo "Username   : $ADMIN_USER"
echo "Password   : $ADMIN_PASS"
echo ""
echo "Jika di Codespaces buka port 8080"
echo "================================="
