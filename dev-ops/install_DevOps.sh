#!/bin/bash

echo -e "\n## Start config for DevOps ##\n"

mkdir -p $application_name/dev-ops/configs/ \
         $application_name/dev-ops/nginx/conf.dev.d/ \
         $application_name/dev-ops/nginx/conf.d/

touch $application_name/dev-ops/configs/.env.dev \
      $application_name/dev-ops/configs/.env

# Add user interaction for choosing node version for docker containers
docker_compose_yml_version=3.8
read -p 'Try latest version of docker-compose.yml? Current 3.8 (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Then, which version docker-compose.yml? : ' docker_compose_yml_version_input
  eval docker_compose_yml_version='$docker_compose_yml_version_input'
fi

# Write docker-compose.dev.yml
cat << EOF > $application_name/dev-ops/docker-compose.$application_name.dev.yml
version: "$docker_compose_yml_version"

services:
  dev_database_$application_name:
    container_name: dev_db_$application_name
    build:
      context: ../database/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev_db_$application_name"
    env_file:
      - ../database/configs/.env.dev
    networks:
      - dev-$application_name-net
    expose:
      - 3306
    restart: unless-stopped

  dev_server_$application_name:
    depends_on:
      - dev_database_$application_name
    container_name: dev_server_$application_name
    build:
      context: ../server/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev_server_$application_name"
    volumes:
      - ../server/:/app/
    env_file:
      - ../server/configs/.env.dev
    networks:
      - dev-$application_name-net
    expose:
      - 3001
    restart: unless-stopped

  dev_client_$application_name:
    depends_on:
      - dev_server_$application_name
    container_name: dev_client_$application_name
    build:
      context: ../client/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev_client_$application_name"
    volumes:
      - ../client/:/app/
    env_file:
      - ../client/configs/.env.dev
    networks:
      - dev-$application_name-net
    expose:
      - 3000
    restart: unless-stopped

  dev_nginx_$application_name:
    depends_on:
      - dev_client_$application_name
    container_name: dev_nginx_$application_name
    image: "nginx:latest"
    volumes:
      - ../dev-ops/nginx/conf.dev.d/:/etc/nginx/conf.d/
    ports:
      - "$dev_port:80"
    networks:
      - dev-$application_name-net
    restart: unless-stopped

networks:
  dev-$application_name-net:
    external: true
EOF

rootDir=$(basename "$PWD")

# Write docker-compose.yml
cat << EOF > $application_name/dev-ops/docker-compose.$application_name.yml
version: "$docker_compose_yml_version"

services:
  database_$application_name:
    container_name: db_$application_name
    build:
      context: ../database/
      dockerfile: Dockerfile
      no_cache: true
    image: "db_$application_name"
    env_file:
      - ../database/configs/.env
    networks:
      - $application_name-net
    expose:
      - 3306
    restart: unless-stopped

  server_$application_name:
    depends_on:
      - database_$application_name
    container_name: server_$application_name
    build:
      context: ../server/
      dockerfile: Dockerfile
      no_cache: true
    image: "server_$application_name"
    env_file:
      - ../server/configs/.env
    networks:
      - $application_name-net
    expose:
      - 3001
    restart: unless-stopped

  client_$application_name:
    depends_on:
      - server_$application_name
    container_name: client_$application_name
    build:
      context: ../client/
      dockerfile: Dockerfile
      no_cache: true
    image: "client_$application_name"
    env_file:
      - ../client/configs/.env
    networks:
      - $application_name-net
    expose:
      - 3000
    restart: unless-stopped

networks:
  $rootDir-net:
    external: true
EOF

# TODO :
# 2. Make cert-bot container and commit

# Write nginx/conf.dev.d
cat << EOF > $application_name/dev-ops/nginx/conf.dev.d/default.conf
upstream dev_client_$application_name {
  server dev_client_$application_name:3000;
}

upstream dev_server_$application_name {
  server dev_server_$application_name:3001;
}

map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  listen [::]:80;

  location / {
    proxy_pass http://dev_client_$application_name;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
  }

  location /api {
    rewrite /api/(.*) /\$1 break;
    proxy_pass http://dev_server_$application_name;
  }
}
EOF

echo -e "\n... Done!\n"
