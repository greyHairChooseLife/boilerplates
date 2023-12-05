#!/bin/bash

echo -e "\n## Start config for DATABASE ##\n"

mkdir -p $application_name/database/configs \
         $application_name/database/initSQL

# Add user interaction for choosing node version for docker containers
docker_container_mariadb_version=latest
read -p 'Try latest version of mariadb for docker container? (y/n): ' use_latest

if [ "$use_latest" = "n" ]; then
  read -e -p 'Which version of mariadb? : ' docker_container_mariadb_version_input
  eval docker_container_mariadb_version='$docker_container_mariadb_version_input'
fi

# Write database/dev.Dockerfile
cat << EOF > $application_name/database/dev.Dockerfile
FROM "mariadb:$docker_container_mariadb_version"

COPY initSQL/*.sql /docker-entrypoint-initdb.d/
EOF

# Write database/Dockerfile
cat << EOF > $application_name/database/Dockerfile
FROM "mariadb:$docker_container_mariadb_version"

COPY initSQL/*.sql /docker-entrypoint-initdb.d/
EOF

# Write .env.dev
cat << EOF > $application_name/database/configs/.env.dev
MYSQL_DATABASE=test
MARIADB_ROOT_PASSWORD=test
EOF

# Write .env
cat << EOF > $application_name/database/configs/.env
MYSQL_DATABASE=prod
MARIADB_ROOT_PASSWORD=prod
EOF

echo -e "\n... Done!\n"
