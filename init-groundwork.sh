#!/bin/bash

# Get the directory of the current script
script_dir="$(dirname "$0")"

# Set the directory name for all the contents
read -p 'directory name for all the contents: ' rootDir

if [ -d "$rootDir" ]; then
  echo "The directory is exists."
  exit 0
else
  mkdir -p $rootDir/dev-ops/nginx/conf.d
fi

# Generate docker-network
docker network create $rootDir-net > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "docker network created: $rootDir-net"
else
  echo "docker network already exists."
fi

# Add user interaction for choosing node version for docker containers
docker_compose_yml_version=3.8
read -p 'Try latest version of docker-compose.yml? Current 3.8 (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Then, which version docker-compose.yml? : ' docker_compose_yml_version_input
  eval docker_compose_yml_version='$docker_compose_yml_version_input'
fi

# Write docker-compose.rootDir.yml
cat << EOF > $rootDir/dev-ops/docker-compose.$rootDir.yml
version: "$docker_compose_yml_version"

services:
  nginx_$rootDir:
    container_name: nginx-$rootDir
    image: "nginx:latest"
    volumes:
      - ../dev-ops/nginx/conf.d/:/etc/nginx/conf.d/
    ports:
      - "80:80"
    networks:
      - $rootDir-net
    restart: unless-stopped

networks:
  $rootDir-net:
    external: true
EOF

# Write nginx/conf.d
cat << EOF > $rootDir/dev-ops/nginx/conf.d/default.conf
server {
  listen 80;
  server_name localhost;

  add_header Content-Type text/plain;
  return 200 'hello world, groundwork is done by name of $HOME/$rootDir/';
}
###
### This is a example of nginx configuration for each APPLICATION
###
###upstream client_\$APPLICATION_NAME {
###  server client_\$APPLICATION_NAME:3000;
###}
###
###upstream server_\$APPLICATION_NAME {
###  server server_\$APPLICATION_NAME:3001;
###}
###
###server {
###  listen 80;
###  listen [::]:80;
###  server_name example.com;
###
###  location /.well-known/acme-challenge/ {
###      root /var/www/certbot;
###  }
###
###  add_header Content-Type text/plain;
###  return 200 'hello world, this is sangyeon kim!!!\n\n\nIf you see this page, \n\n 1) go get a SSL certificate by running script. You may find ./help if you need.\n\n2) manage nginx config to redirect to 443. It means remove annotations in front of "return 301 https://...."';
###
######  return 301 https://$host$request_uri;
###}
###
###server {
###  listen 443 ssl;
###  listen [::]:443 ssl;
###  server_name example.com;
###
###  ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
###  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
###
###  location / {
###    proxy_pass http://client_\$APPLICATION_NAME;
###  }
###
###  location /api {
###    rewrite /api/(.*) /$1 break;
###    proxy_pass http://server_\$APPLICATION_NAME;
###  }
###}
EOF

echo -e "\nFinish groundwork! Let's make new application!!\n\n"
