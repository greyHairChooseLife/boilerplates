#!/bin/bash

# Get the directory of the current script
script_dir="$(dirname "$0")"

# Set the directory name for all the contents
read -p 'directory name for all the contents: ' rootDir

if [ -d "$rootDir" ]; then
  echo "The directory is exists."
  exit 0
else
  mkdir -p $rootDir/dev-ops/nginx/conf.d \
           $rootDir/configs \
           $rootDir/commanders/commands \
           $rootDir/apps
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
    container_name: prod-$rootDir-web_server
    image: "nginx:latest"
    volumes:
      - ../dev-ops/nginx/conf.d/:/etc/nginx/conf.d/
      - ../dev-ops/certbot/conf/:/etc/letsencrypt/:ro
      - ../dev-ops/certbot/www:/var/www/certbot/:ro
    ports:
      - "80:80"
      - "443:443"
    networks:
      - $rootDir-net
    restart: unless-stopped

  certbot:
    image: certbot/certbot:latest
    volumes:
      - ../dev-ops/certbot/conf/:/etc/letsencrypt/:ro
      - ../dev-ops/certbot/www:/var/www/certbot/:ro

networks:
  $rootDir-net:
    external: true
EOF

# Write nginx/conf.d
cat << EOF > $rootDir/dev-ops/nginx/conf.d/default.conf
###server {
###  listen 80;
###  server_name localhost;
###
###  add_header Content-Type text/plain;
###  return 200 'hello world, groundwork is done by name of $HOME/$rootDir/';
###}
###
### This is a example of nginx configuration for each APPLICATION
###
upstream prod-\$APPLICATION_NAME-client {
  server prod-\$APPLICATION_NAME-client:3000;
}

upstream prod-\$APPLICATION_NAME-server {
  server prod-\$APPLICATION_NAME-server:3001;
}

server {
  listen 80;
  listen [::]:80;
  server_name example.com;

  location /.well-known/acme-challenge/ {
      root /var/www/certbot;
  }

  location / {
    proxy_pass http://prod-\$APPLICATION_NAME-client;
  }
###
###  return 301 https://\$host\$request_uri;
###
### 1. 일단 이 상태로 SSL 인증서 받는다.
###     >> docker-compose -f <이 nginx.conf를 활용하는 nginx 서버를 실행하는 docker-compose.yml파일> run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d example.com
### 2. 인증서 받은 후에 return 301 https://\$host\$request_uri; 주석 해제, 443으로 리다이렉트 해준다.
###
###
}

###server {
###  listen 443 ssl;
###  listen [::]:443 ssl;
###  server_name example.com;
###
###  ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
###  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
###
###  location / {
###    proxy_pass http://prod-\$APPLICATION_NAME-client;
###  }
###
###  location /api {
###    rewrite /api/(.*) /$1 break;
###    proxy_pass http://prod-\$APPLICATION_NAME-server;
###  }
###}
EOF

# Write commander.sh
cat << EOF > $rootDir/commanders/commander.sh
#!/bin/bash

echo -e "\nList of running compose projects:\n"
docker compose ls

script_dir="\$(dirname "\$0")"

# Function to display main menu
show_menu() {
  echo -e "\nList of applications:\n"

  # Dynamically list available commands from the 'commands' subdirectory
  commands_list=(\$(ls \$script_dir/commands/))

  for ((i=0; i<\${#commands_list[@]}; i++)); do
      echo "  \$((i+1)). Run \${commands_list[i]}"
  done

  echo -e "  0. Exit\n"
}

# Function to execute selected command
execute_command() {
  if [ "\$1" -eq 0 ]; then
    echo -e "Exiting script.\n"
    exit
  elif [ "\$1" -le "\${#commands_list[@]}" ]; then
    # Correctly calculate the index based on the user input
    selected_command="\${commands_list[\$((choice - 1))]}"
    echo -e "Executing: \$selected_command\n"
    source "\$script_dir/commands/\$selected_command"
  else
    echo "Invalid option"
  fi
}

# Main script logic
while true; do
  show_menu
  read -p "Enter your choice (0-\${#commands_list[@]}): " choice
  execute_command \$choice
done
EOF

# Write sub-command
# Write nginx container initiative script to `docker-compose up and down`
cat << EOF > $rootDir/commanders/commands/init-prod-nginx.sh
#!/bin/bash

read -p "Want to check which docker compose projects are running? (y/n): " check_compose

if [ "\$check_compose" = "y" ]; then
  docker compose ls
fi

script_dir="\$(dirname "\$0")"
echo -e "\ndocker compose project name: $rootDir"
echo -e "running commands: \n"
echo -e "  docker compose -p prod-$rootDir-web_server -f \$(dirname \$script_dir)/dev-ops/docker-compose.$rootDir.yml up -d --build"
echo -e "  docker compose -p prod-$rootDir-web_server down --rmi all\n"

read -p "Up or Down? (u/d): " up_or_down

if [ "\$up_or_down" = "u" ]; then
  docker compose -p prod-$rootDir-web_server -f \$(dirname \$script_dir)/dev-ops/docker-compose.$rootDir.yml up -d --build
else
  docker compose -p prod-$rootDir-web_server down --rmi all
fi
EOF

# Write sub-command
# Write script to get SSL certificate from certbot
cat << EOF > $rootDir/commanders/commands/get-ssl-cert.sh
#!/bin/bash
# Get SSL certificate from certbot
# https://certbot.eff.org/docs/using.html#renewing-certificates

# Help message for myself
echo -e "\n  This script is for getting SSL certificate from certbot.\n"
echo -e "  You can get SSL certificate from certbot by running this script.\n"
echo -e "  korean blog reference: https://qspblog.com/blog/SSL-%EC%9D%B8%EC%A6%9D-%EB%B0%9B%EA%B8%B0-docker-%EC%82%AC%EC%9A%A9-certbot-%EC%9C%BC%EB%A1%9C-certificates-%EB%B0%9B%EA%B8%B0-https%EB%A1%9C-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0-php%EC%99%80-nginx-%EC%9B%B9%EC%84%9C%EB%B2%84#certbot-%EB%8F%84%EC%BB%A4-%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88"
echo -e "  korean git reference: https://github.com/terrificmn/docker-laravel#https-%EC%9D%B8%EC%A6%9D-%EB%B0%9B%EA%B8%B0\n"

domain_name=example.com
read -p "domain name: " domain_name
script_dir="\$(dirname "\$0")"
docker_compose_configuration="\$(dirname \$script_dir)/dev-ops/docker-compose.$rootDir.yml"

docker compose -f \$docker_compose_configuration run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d \$domain_name
EOF

echo -e "\n  Groundwork finish..! Let's make something!!\n"

tree $rootDir
