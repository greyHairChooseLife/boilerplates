#!/bin/bash

echo -e "\n## Start config for CLIENT-SIDE ##\n"

mkdir -p $project_name/client/configs

touch $project_name/client/configs/.env.dev \
      $project_name/client/configs/.env \

# Add user interaction for choosing node version for docker containers
docker_container_node_version=latest
read -p 'Try latest version of node for docker container? (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Which version of node? : ' docker_container_node_version_input
  eval docker_container_node_version='$docker_container_node_version_input'
fi

# Write client/dev.Dockerfile
cat << EOF > $project_name/client/dev.Dockerfile
FROM "node:$docker_container_node_version"

WORKDIR /app

COPY package*.json ./

RUN npm i

COPY . .

CMD PORT=3000 npm run dev
EOF

# Write client/Dockerfile
cat << EOF > $project_name/client/Dockerfile
# Stage 1: Build the application
FROM "node:$docker_container_node_version" as build
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build

# Stage 2: Deploy with built only
FROM nginx:latest
COPY --from=build /app/build /usr/share/nginx/html
CMD nginx -g daemon off;
EOF

echo -e "\n... Done!\n"
