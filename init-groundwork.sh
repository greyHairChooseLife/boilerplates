#!/bin/bash

# Get the directory of the current script
script_dir="$(dirname "$0")"

# Set the directory name for all the contents
read -p 'directory name for all the contents: ' rootDir

if [ -d "$rootDir" ]; then
  echo "The directory is exists."
  exit 0
else
  mkdir $rootDir
fi

# Generate docker-network
docker network create $rootDir-net > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "docker network created: $rootDir-net"
else
  echo "docker network already exists."
fi

echo -e "\nFinish groundwork! Good luck!!\n"
