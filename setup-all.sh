#!/bin/bash
set -euo pipefail

PROJECT_PATH=$HOME/Work/on_prem_workup
COMPOSE_FILE="./docker-compose.yml"


# KEYCLOAK AUTH SETUP
cd ${PROJECT_PATH}/app/auth
docker compose down -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans
./bootstrap.sh

sleep 15

# FRONTEND APP SETUP
cd ${PROJECT_PATH}/app/frontend
docker compose down -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans

# BACKEND APP SETUP
cd ${PROJECT_PATH}/app/backend
go mod tidy -e -x -v
docker compose down  -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans

# OBSERVABILITY SETUP
cd ${PROJECT_PATH}/monitoring
docker compose down  -v
docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans




