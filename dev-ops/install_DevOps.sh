#!/bin/bash

echo -e "\n## Start config for DevOps ##\n"

mkdir -p $project_name/dev-ops/configs/ \
         $project_name/dev-ops/nginx/conf.dev.d/ \
         $project_name/dev-ops/nginx/conf.d/

touch $project_name/dev-ops/configs/.env.dev \
      $project_name/dev-ops/configs/.env

# Add user interaction for choosing node version for docker containers
docker_compose_yml_version=3.8
read -p 'Try latest version of docker-compose.yml? Current 3.8 (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Then, which version docker-compose.yml? : ' docker_compose_yml_version_input
  eval docker_compose_yml_version='$docker_compose_yml_version_input'
fi

# Write docker-compose.dev.yml
cat << EOF > $project_name/dev-ops/docker-compose.$project_name.dev.yml
version: $docker_compose_yml_version

services:
  dev_database_$project_name:
    container_name: dev_db_$project_name
    build:
      context: ../database/
      dockerfile: dev.Dockerfile
    image: "dev_db_$project_name"
    env_file:
      - ../database/configs/.env.dev
    networks:
      - dev-$project_name-net
    expose:
      - 3306
    restart: unless-stopped

  dev_server_$project_name:
    depends_on:
      - dev_database_$project_name
    container_name: dev_server_$project_name
    build:
      context: ../server/
      dockerfile: dev.Dockerfile
    image: "dev_server_$project_name"
    volumes:
      - ../server/:/app/
    env_file:
      - ../server/configs/.env.dev
    networks:
      - dev-$project_name-net
    expose:
      - 3001
    restart: unless-stopped

  dev_client_$project_name:
    depends_on:
      - dev_server_$project_name
    container_name: dev_client_$project_name
    build:
      context: ../client/
      dockerfile: dev.Dockerfile
    image: "dev_client_$project_name"
    volumes:
      - ../client/:/app/
    env_file:
      - ../client/configs/.env.dev
    networks:
      - dev-$project_name-net
    expose:
      - 3000
    restart: unless-stopped

  dev_nginx_$project_name:
    depends_on:
      - dev_client_$project_name
    container_name: dev_nginx_$project_name
    image: "nginx:latest"
    volumes:
      - ../dev-ops/nginx/conf.dev.d/:/etc/nginx/conf.d/
    ports:
      - "$dev_port:80"
    networks:
      - dev-$project_name-net
    restart: unless-stopped

networks:
  dev-$project_name-net:
    external: true
EOF

# Write docker-compose.yml
cat << EOF > $project_name/dev-ops/docker-compose.$project_name.yml
version: $docker_compose_yml_version

services:
  database_$project_name:
    container_name: db_$project_name
    build:
      context: ../database/
      dockerfile: Dockerfile
    image: "db_$project_name"
    env_file:
      - ../database/configs/.env
    networks:
      - $project_name-net
    expose:
      - 3306
    restart: unless-stopped

  server_$project_name:
    depends_on:
      - database_$project_name
    container_name: server_$project_name
    build:
      context: ../server/
      dockerfile: Dockerfile
    image: "server_$project_name"
    env_file:
      - ../server/configs/.env
    networks:
      - $project_name-net
    expose:
      - 3001
    restart: unless-stopped

  client_$project_name:
    depends_on:
      - server_$project_name
    container_name: client_$project_name
    build:
      context: ../client/
      dockerfile: Dockerfile
    image: "client_$project_name"
    env_file:
      - ../client/configs/.env
    networks:
      - $project_name-net
    expose:
      - 3000
    restart: unless-stopped

  nginx_$project_name:
    depends_on:
      - client_$project_name
    container_name: nginx_$project_name
    image: "nginx:latest"
    volumes:
      - ../dev-ops/nginx/conf.d/:/etc/nginx/conf.d/
    ports:
      - "80:80"
    networks:
      - $project_name-net
    restart: unless-stopped

networks:
  $project_name-net:
    external: true
EOF

# TODO :
# 2. Make cert-bot container and commit

# Write nginx/conf.dev.d
cat << EOF > $project_name/dev-ops/nginx/conf.dev.d/default.conf
upstream dev_client_$project_name {
  server dev_client_$project_name:3000;
}

upstream dev_server_$project_name {
  server dev_server_$project_name:3001;
}

server {
  listen 80;
  listen [::]:80;

  location / {
    proxy_pass http://dev_client_$project_name;
  }

  location /api {
    rewrite /api/(.*) /$1 break;
    proxy_pass http://dev_server_$project_name;
  }
}
EOF

# Write nginx/conf.d
cat << EOF > $project_name/dev-ops/nginx/conf.d/default.conf
upstream client_$project_name {
  server client_$project_name:3000;
}

upstream server_$project_name {
  server server_$project_name:3001;
}

server {
  listen 80;
  listen [::]:80;

  location / {
    proxy_pass http://client_$project_name;
  }

  location /api {
    rewrite /api/(.*) /$1 break;
    proxy_pass http://server_$project_name;
  }
}
EOF

echo -e "\n... Done!\n"
