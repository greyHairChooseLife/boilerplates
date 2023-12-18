#!/bin/bash

echo -e "\n## Start config for SERVER-SIDE ##\n"

mkdir -p $application_name/server/configs

# Add user interaction for choosing node version for docker containers
docker_container_node_version=latest
read -p 'Try latest version of node for docker container? (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Which version of node? : ' docker_container_node_version_input
  eval docker_container_node_version='$docker_container_node_version_input'
fi

# Write server/dev.Dockerfile
cat << EOF > $application_name/server/dev.Dockerfile
FROM "node:$docker_container_node_version"

WORKDIR /app

CMD npm run dev
EOF

# Write server/Dockerfile
cat << EOF > $application_name/server/Dockerfile
# Stage 1: Build the application
FROM "node:$docker_container_node_version" as build
WORKDIR /app
COPY . .
RUN npm install
RUN npx tsc --outDir "./dist"

# Stage 2: Deploy with necessary things
FROM "node:$docker_container_node_version"
WORKDIR /app
COPY package*.json ./
COPY --from=build /app/dist .
RUN npm ci --omit=dev
CMD node ./index.js
EOF

# Write .env.dev
cat << EOF > $application_name/server/configs/.env.dev
DB_HOST="dev_database_$application_name" #service name of docker-compose.yml
DB_PORT=3306

DB_DATABASE=test
DB_PASS=test
DB_USER=root

SESSION_SECRET=test-session
EOF

# Write .env
cat << EOF > $application_name/server/configs/.env
DB_HOST="database_$application_name" #service name of docker-compose.yml
DB_PORT=3306

DB_DATABASE=prod
DB_PASS=prod
DB_USER=root

SESSION_SECRET=prod-session
EOF

echo -e "\n... Done!\n"
