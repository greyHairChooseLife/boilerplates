#!/bin/bash

# Get the directory of the current script
script_dir="$(dirname "$0")"

# Set project name and Make the directory
read -p 'project name: ' project_name

if [ -d "$project_name" ]; then
  echo "The directory is exists."
  exit 0
else
  mkdir $project_name
fi

# Generate docker network
docker network create dev-$project_name-net > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "docker network created: dev-$project_name-net"
else
  echo "docker network already exists."
fi

# Set dev port
read -p 'select [dev server] port number: ' dev_port

# Add user interaction for choosing Prettier config file
# User can choose default config file
read -p 'Do you want to use the default .prettierrc file? (y/n): ' use_default

if [ "$use_default" = "y" ]; then
cat << EOF > "$project_name/.prettierrc"
  {
    "tabWidth": 2,
    "semi": true,
    "singleQuote": true,
    "trailingComma": "all",
    "printWidth": 80,
    "useTabs": false,
    "endOfLine": "auto"
  }
EOF
else
  read -e -p 'Provide the path to the .prettierrc config file: ' prettierrc_input
  eval prettierrc='$prettierrc_input'
  cp $prettierrc $project_name/
fi

source $script_dir/client/install_client.sh
source $script_dir/server/install_server.sh

# make directories
mkdir -p $project_name/dev_ops/configs \
         $project_name/db/configs \
         $project_name/db/initSQL \

touch $project_name/dev_ops/configs/.env.dev \
      $project_name/dev_ops/configs/.env \
      $project_name/db/configs/.env.dev \
      $project_name/db/configs/.env \

# make docker-compose.yml : Developing 
cd $project_name/dev_ops
cat << EOF > docker-compose.$project_name.dev.yml
version: "3"

services:
  dev_db_$project_name:
    container_name: dev_db_$project_name
    build:
      context: ../db/
      dockerfile: dev.Dockerfile
    image: "dev_db_$project_name"
    env_file:
      - ../db/configs/.env.dev
    networks:
      - dev-$project_name-net

  dev_server_$project_name:
    depends_on:
      - dev_db_$project_name
    container_name: dev_back_$project_name
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
      - ../dev_ops/configs/nginx/conf.dev.d/:/etc/nginx/conf.d/
    ports:
      - "$dev_port:80"
    networks:
      - dev-$project_name-net

networks:
  dev-$project_name-net:
    external: true
EOF

# make db/dev.Dockerfile
cd ~/$project_name/db
cat << EOF > dev.Dockerfile
FROM mariadb:10.11

COPY initSQL/*.sql /docker-entrypoint-initdb.d/
EOF

# make db/Dockerfile
cd ~/$project_name/db
cat << EOF > Dockerfile
FROM mariadb:10.11

COPY initSQL/*.sql /docker-entrypoint-initdb.d/
EOF
