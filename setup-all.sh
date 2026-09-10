#!/bin/bash
set -euo pipefail

PROJECT_PATH=$HOME/on_prem_workup
COMPOSE_FILE="./docker-compose.yml"


# # KEYCLOAK AUTH SETUP
# cd ${PROJECT_PATH}/app/auth
# docker compose down -v
# docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans
# ./bootstrap.sh

# sleep 15

# # FRONTEND APP SETUP
# cd ${PROJECT_PATH}/app/frontend
# docker compose down -v
# docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans

# # BACKEND APP SETUP
# cd ${PROJECT_PATH}/app/backend
# go mod tidy -e -x -v
# docker compose down  -v
# docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans

# # OBSERVABILITY SETUP
# cd ${PROJECT_PATH}/observability
# docker compose down  -v
# docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans


# # TEMPLATE STEP

cd ${PROJECT_PATH}/infra

./template.sh


# TERRAFORM SETUP

cd ${PROJECT_PATH}/infra/terraform

terraform apply --auto-approve


# ANSIBLE SETUP

cd ${PROJECT_PATH}/infra/ansible

ansible-playbook playbooks/frontend.yml