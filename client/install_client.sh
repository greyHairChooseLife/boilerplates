#!/bin/bash

mkdir -p $project_name/client/configs

touch $project_name/client/configs/.env.dev \
      $project_name/client/configs/.env \

# Write client/dev.Dockerfile
cat << EOF > $project_name/client/dev.Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY package*.json ./

RUN npm i

COPY . .

CMD PORT=3000 npm run dev
EOF

# Write client/Dockerfile
cat << EOF > $project_name/client/Dockerfile
FROM node:14-alpine

WORKDIR /app

COPY build/ .

RUN npm install -g serve

CMD serve -s build -l 3000
EOF
