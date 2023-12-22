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
    container_name: dev-$application_name-DB
    build:
      context: ../database/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev-$application_name-DB"
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
    container_name: dev-$application_name-server
    build:
      context: ../server/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev-$application_name-server"
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
    container_name: dev-$application_name-client
    build:
      context: ../client/
      dockerfile: dev.Dockerfile
      no_cache: true
    image: "dev-$application_name-client"
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
    container_name: dev-$application_name-web_server
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

groundWorkDir=$(basename $(dirname $PWD))

# Write docker-compose.yml
cat << EOF > $application_name/dev-ops/docker-compose.$application_name.yml
version: "$docker_compose_yml_version"

services:
  database_$application_name:
    container_name: prod-$application_name-DB
    build:
      context: ../database/
      dockerfile: Dockerfile
      no_cache: true
    image: "prod-$application_name-DB"
    env_file:
      - ../database/configs/.env
    networks:
      - $groundWorkDir-net
    expose:
      - 3306
    restart: unless-stopped

  server_$application_name:
    depends_on:
      - database_$application_name
    container_name: prod-$application_name-server
    build:
      context: ../server/
      dockerfile: Dockerfile
      no_cache: true
    image: "prod-$application_name-server"
    env_file:
      - ../server/configs/.env
    networks:
      - $groundWorkDir-net
    expose:
      - 3001
    restart: unless-stopped

  client_$application_name:
    depends_on:
      - server_$application_name
    container_name: prod-$application_name-client
    build:
      context: ../client/
      dockerfile: Dockerfile
      no_cache: true
    image: "prod-$application_name-client"
    env_file:
      - ../client/configs/.env
    networks:
      - $groundWorkDir-net
    expose:
      - 3000
    restart: unless-stopped

networks:
  $groundWorkDir-net:
    external: true
EOF

# TODO :
# 2. Make cert-bot container and commit

# Write nginx/conf.dev.d
cat << EOF > $application_name/dev-ops/nginx/conf.dev.d/default.conf
upstream dev-$application_name-client {
  server dev-$application_name-client:3000;
}

upstream dev-$application_name-server {
  server dev-$application_name-server:3001;
}

map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  listen [::]:80;

  location / {
    proxy_pass http://dev-$application_name-client;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
  }

  location /api {
    rewrite /api/(.*) /\$1 break;
    proxy_pass http://dev-$application_name-server;
  }
}
EOF

echo -e "\n... Done!\n"
