#!/bin/bash

# Set project name and Make the directory
read -p 'project name: ' project_name

if [ -d "$project_name" ]; then
  echo "The directory is exists."
  exit 0
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

# make directories
mkdir -p $project_name/dev_ops/configs \
         $project_name/db/configs \
         $project_name/db/initSQL \
         $project_name/server/configs \
         $project_name/client/configs \

read -e -p 'provide .prettierrc config file: ' prettierrc_input
eval prettierrc='$prettierrc_input'
cp $prettierrc $project_name/


touch $project_name/dev_ops/configs/.env.dev \
      $project_name/dev_ops/configs/.env \
      $project_name/db/configs/.env.dev \
      $project_name/db/configs/.env \
      $project_name/server/configs/.env.dev \
      $project_name/server/configs/.env \
      $project_name/client/configs/.env.dev \
      $project_name/client/configs/.env \

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

# make server/dev.Dockerfile
cd ~/$project_name/server
cat << EOF > dev.Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY . .

RUN npm i

CMD npm run dev
EOF

# make server/Dockerfile
cd ~/$project_name/server
cat << EOF > Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY package*.json ./

RUN npm i --only production

COPY dist/ ./

CMD [ "node", "./index.js" ]
EOF

# make client/dev.Dockerfile
cd ~/$project_name/client
cat << EOF > dev.Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY package*.json ./

RUN npm i

COPY . .

CMD PORT=3000 npm run dev
EOF

# make client/Dockerfile
cd ~/$project_name/client
cat << EOF > Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY build/ .

RUN npm install -g serve

CMD serve -s build -l 3000
EOF
