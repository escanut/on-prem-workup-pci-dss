
COMPOSE_FILE="./docker-compose.yml"

docker compose -f ${COMPOSE_FILE} up --build -d --remove-orphans

echo "Small time before running bootstrap script for keycloak"
sleep 15

./bootstrap.sh