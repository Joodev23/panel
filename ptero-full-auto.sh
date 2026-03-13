#!/bin/bash

echo "=============================="
echo "PTERODACTYL FULL AUTO SETUP"
echo "=============================="

ADMIN_EMAIL="admin@panel.local"
ADMIN_USER="admin"
ADMIN_PASS="Admin123!"
FIRST_NAME="Admin"
LAST_NAME="Panel"

mkdir -p ptero/srv/{database,var,logs,wings,daemon}
cd ptero

echo "[1/8] membuat docker compose..."

cat > docker-compose.yml << 'EOF'
version: "3.8"

services:
  database:
    image: mariadb:10.5
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: panel
      MYSQL_USER: pterodactyl
      MYSQL_PASSWORD: panelpass
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
      DB_PASSWORD: "panelpass"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"

  wings:
    image: ghcr.io/pterodactyl/wings:latest
    restart: always
    ports:
      - "2022:2022"
    volumes:
      - "./srv/wings:/etc/pterodactyl"
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./srv/daemon:/var/lib/pterodactyl"
EOF

echo "[2/8] start container..."
docker compose up -d

echo "[3/8] tunggu database..."
sleep 25

echo "[4/8] migrate database..."
docker compose run --rm panel php artisan migrate --seed --force

echo "[5/8] generate key..."
docker compose run --rm panel php artisan key:generate --force

echo "[6/8] buat admin..."
docker compose run --rm panel php artisan p:user:make \
 --email=$ADMIN_EMAIL \
 --username=$ADMIN_USER \
 --name-first=$FIRST_NAME \
 --name-last=$LAST_NAME \
 --password=$ADMIN_PASS \
 --admin=1

echo "[7/8] restart panel..."
docker compose restart panel

echo "[8/8] setup selesai"

echo "=============================="
echo "LOGIN PANEL"
echo "=============================="
echo "URL  : http://localhost:8080"
echo "USER : $ADMIN_USER"
echo "PASS : $ADMIN_PASS"

echo ""
echo "PORT PANEL: 8080"
echo "PORT NODE : 2022"
