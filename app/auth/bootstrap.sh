#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

KEYCLOAK_URL="http://localhost:8080"
FRONTEND_URL="https://www.victorojeje.xyz"
SECONDARY_URL="https://victorojeje.xyz"

ADMIN_USER="admin"
ADMIN_PASS="${KC_ADMIN_PASSWORD:?KC_ADMIN_PASSWORD not set}"

REALM_NAME="workup"
CLIENT_ID="workup-frontend"

echo "Waiting for Keycloak to be ready..."
until curl -sf "${KEYCLOAK_URL}/realms/master" >/dev/null 2>&1; do
  sleep 2
done
echo "Keycloak is ready."

echo "Getting admin token..."
ADMIN_TOKEN=$(curl -sf -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "${ADMIN_TOKEN}" ] || [ "${ADMIN_TOKEN}" = "null" ]; then
  echo "Failed to get admin token. Check credentials."
  exit 1
fi

# --------------------------------------------------------------------
# Realm
# --------------------------------------------------------------------

echo "Checking for realm: ${REALM_NAME}..."
REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

if [ "${REALM_STATUS}" = "200" ]; then
  echo "Realm already exists. Updating realm settings..."

  UPDATE_STATUS=$(curl -s -o /tmp/realm_update.json -w "%{http_code}" -X PUT \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"realm\": \"${REALM_NAME}\",
      \"enabled\": true,
      \"sslRequired\": \"external\",
      \"loginTheme\": \"keycloak\",
      \"accessTokenLifespan\": 300,
      \"ssoSessionIdleTimeout\": 1800,
      \"registrationAllowed\": true,
      \"registrationEmailAsUsername\": true,
      \"verifyEmail\": true,
      \"resetPasswordAllowed\": true
    }")

  if [ "${UPDATE_STATUS}" = "204" ]; then
    echo "Realm settings updated."
  else
    echo "Realm update failed (HTTP ${UPDATE_STATUS}):"
    cat /tmp/realm_update.json
    exit 1
  fi

else
  echo "Creating realm: ${REALM_NAME}..."

  CREATE_STATUS=$(curl -s -o /tmp/realm_create.json -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"realm\": \"${REALM_NAME}\",
      \"enabled\": true,
      \"sslRequired\": \"external\",
      \"loginTheme\": \"keycloak\",
      \"accessTokenLifespan\": 300,
      \"ssoSessionIdleTimeout\": 1800,
      \"registrationAllowed\": true,
      \"registrationEmailAsUsername\": true,
      \"verifyEmail\": false,
      \"resetPasswordAllowed\": true
    }")

  if [ "${CREATE_STATUS}" = "201" ]; then
    echo "Realm created."
  else
    echo "Realm creation failed (HTTP ${CREATE_STATUS}):"
    cat /tmp/realm_create.json
    exit 1
  fi
fi

# --------------------------------------------------------------------
# Client
# --------------------------------------------------------------------

echo "Checking for client: ${CLIENT_ID}..."

EXISTING_CLIENT=$(curl -sf \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r 'length')

if [ "${EXISTING_CLIENT}" != "0" ]; then
  echo "Client already exists. Skipping creation."
else
  echo "Creating client: ${CLIENT_ID}..."

  CREATE_STATUS=$(curl -s -o /tmp/client_create.json -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"${CLIENT_ID}\",
      \"name\": \"WorkUp Frontend\",
      \"enabled\": true,
      \"publicClient\": true,
      \"baseUrl\": \"${FRONTEND_URL}\",
      \"redirectUris\": [
        \"${FRONTEND_URL}/*\",
        \"${SECONDARY_URL}/*\"
      ],
      \"webOrigins\": [
        \"${FRONTEND_URL}\",
        \"${SECONDARY_URL}\"
      ],
      \"standardFlowEnabled\": true,
      \"implicitFlowEnabled\": false,
      \"directAccessGrantsEnabled\": false,
      \"attributes\": {
        \"pkce.code.challenge.method\": \"S256\"
      }
    }")

  if [ "${CREATE_STATUS}" = "201" ]; then
    echo "Client created."
  else
    echo "Client creation failed (HTTP ${CREATE_STATUS}):"
    cat /tmp/client_create.json
    exit 1
  fi
fi

rm -f \
  /tmp/realm_create.json \
  /tmp/realm_update.json \
  /tmp/client_create.json

echo
echo "Bootstrap complete."
echo
echo "OIDC discovery URL:"
echo "  ${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration"
echo
echo "Frontend config:"
echo "  KEYCLOAK_URL: '${KEYCLOAK_URL}'"
echo "  REALM: '${REALM_NAME}'"
echo "  CLIENT_ID: '${CLIENT_ID}'"