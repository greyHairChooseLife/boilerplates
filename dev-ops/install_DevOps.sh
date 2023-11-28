#!/bin/bash

echo -e "\n## Start config for DevOps ##\n"

mkdir -p $project_name/dev-ops/configs

touch $project_name/dev-ops/configs/.env.dev \
      $project_name/dev-ops/configs/.env

# Add user interaction for choosing node version for docker containers
docker_compose_yml_version=3.8
read -p 'Try latest version of docker-compose.yml? Current 3.8 (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Then, which version docker-compose.yml? : ' docker_compose_yml_version_input
  eval docker_compose_yml_version='$docker_compose_yml_version_input'
fi

# Write docker-compose.yml : Developing 
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

  dev_nginx_$project_name:
    depends_on:
      - dev_client_$project_name
    container_name: dev_nginx_$project_name
    image: "nginx:latest"
    volumes:
      - ../dev-ops/configs/nginx/conf.dev.d/:/etc/nginx/conf.d/
    ports:
      - "$dev_port:80"
    networks:
      - dev-$project_name-net

networks:
  dev-$project_name-net:
    external: true
EOF

echo -e "\n... Done!\n"
