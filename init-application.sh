#!/bin/bash

# Get the directory of the current script
script_dir="$(dirname "$0")"

# Set application name and Make the directory
read -p 'application name: ' application_name

if [ -d "$application_name" ]; then
  echo "The directory is exists."
  exit 0
else
  mkdir $application_name
fi

# Generate dev-docker-network
docker network create dev-$application_name-net > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "docker network created: dev-$application_name-net"
else
  echo "docker dev-network already exists."
fi

# Set dev port
read -p 'select [dev server] port number: ' dev_port

# Add user interaction for choosing Prettier config file
# User can choose default config file
read -p 'Do you want to use the default .prettierrc file? (y/n): ' use_default

if [ "$use_default" = "y" ]; then
cat << EOF > "$application_name/.prettierrc"
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
  cp $prettierrc $application_name/
fi

source $script_dir/client/install_client.sh
source $script_dir/server/install_server.sh
source $script_dir/database/install_db.sh
source $script_dir/dev-ops/install_DevOps.sh
