#!/bin/bash

[[ $(docker ps -f name=nginx -q -a) != '' ]] && docker rm --force $(docker ps -f name=nginx -q -a)
docker compose up -d --no-deps --build --force-recreate
docker image prune -a --force
