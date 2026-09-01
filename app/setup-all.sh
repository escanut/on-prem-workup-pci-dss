#!/bin/bash
set -euo pipefail

PROJECT_PATH=$HOME/Work/on_prem_workup/app
COMPOSE_FILE="./docker-compose.yml"


# KEYCLOAK AUTH SETUP
cd ${PROJECT_PATH}/auth
docker compose down -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans


./bootstrap.sh


cd ${PROJECT_PATH}/frontend

docker compose down -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans
