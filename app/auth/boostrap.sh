#!/bin/bash
set -e

KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="${KC_ADMIN_PASSWORD}"
REALM_NAME="workup"
CLIENT_ID="workup-frontend"

echo "Waiting for Keycloak to be ready..."
until curl -sf "${KEYCLOAK_URL}/health/ready" > /dev/null 2>&1; do
    sleep 2
done
echo "Keycloak is ready."

echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "Failed to get admin token. Check credentials."
    exit 1
fi

echo "Creating realm: ${REALM_NAME}..."
curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"realm\": \"${REALM_NAME}\",
    \"enabled\": true,
    \"sslRequired\": \"external\",
    \"loginTheme\": \"keycloak\",
    \"accessTokenLifespan\": 300,
    \"ssoSessionIdleTimeout\": 1800
  }" | grep -q "201" && echo "Realm created." || echo "Realm may already exist."

echo "Creating client: ${CLIENT_ID}..."
curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"${CLIENT_ID}\",
    \"name\": \"WorkUp Frontend\",
    \"enabled\": true,
    \"publicClient\": true,
    \"redirectUris\": [\"https://victorojeje.xyz/*\", \"http://localhost:5500/*\"],
    \"webOrigins\": [\"https://victorojeje.xyz\", \"http://localhost:5500\"],
    \"standardFlowEnabled\": true,
    \"implicitFlowEnabled\": false,
    \"directAccessGrantsEnabled\": false,
    \"attributes\": {
      \"pkce.code.challenge.method\": \"S256\"
    }
  }" | grep -q "201" && echo "Client created." || echo "Client may already exist."

echo "Bootstrap complete."
echo ""
echo "Keycloak OIDC discovery URL: ${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration"
echo "Update your frontend config.js with:"
echo "  KEYCLOAK_URL: '${KEYCLOAK_URL}'"
echo "  REALM: '${REALM_NAME}'"
echo "  CLIENT_ID: '${CLIENT_ID}'"