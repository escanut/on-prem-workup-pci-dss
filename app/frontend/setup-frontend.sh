
COMPOSE_FILE="./docker-compose.yml"

docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans
