#!/bin/bash

echo -e "\n## Start config for SERVER-SIDE ##\n"

mkdir -p $project_name/server/configs

touch $project_name/server/configs/.env.dev \
      $project_name/server/configs/.env

# Add user interaction for choosing node version for docker containers
docker_container_node_version=latest
read -p 'Try latest version of node for docker container? (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Which version of node? : ' docker_container_node_version_input
  eval docker_container_node_version='$docker_container_node_version_input'
fi

# Write server/dev.Dockerfile
cat << EOF > $project_name/server/dev.Dockerfile
FROM "node:$docker_container_node_version"

WORKDIR /app

COPY . .

RUN npm i

CMD npm run dev
EOF

# Write server/Dockerfile
cat << EOF > $project_name/server/Dockerfile
FROM "node:$docker_container_node_version"

WORKDIR /app

COPY package*.json ./

RUN npm i --only production

COPY dist/ ./

CMD node ./index.js
EOF

echo -e "\n... Done!\n"
