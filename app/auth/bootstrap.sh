#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

KEYCLOAK_URL="http://localhost:8080"
AUTH_URL="https://auth.victorojeje.xyz"


FRONTEND_URL="https://www.victorojeje.xyz"
SECONDARY_URL="https://victorojeje.xyz"


GRAFANA_CLIENT_ID="grafana"
GRAFANA_URL="https://grafana.victorojeje.xyz"


CLOUDFLARE_TEAM_NAME="${CLOUDFLARE_TEAM_NAME:?CLOUDFLARE_TEAM_NAME not set}"
CLOUDFLARE_CALLBACK="https://${CLOUDFLARE_TEAM_NAME}.cloudflareaccess.com/cdn-cgi/access/callback"

ADMIN_USER="${KC_ADMIN_USERNAME:?KC_ADMIN_USERNAME not set}"
ADMIN_PASS="${KC_ADMIN_PASSWORD:?KC_ADMIN_PASSWORD not set}"

REALM_NAME="workup"
CLIENT_ID="workup-frontend"
CF_CLIENT_ID="cloudflare-access"          

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

# Shared by create + update so the two paths stay identical
REALM_SETTINGS=$(cat <<EOF
{
  "realm": "${REALM_NAME}",
  "enabled": true,
  "sslRequired": "external",
  "loginTheme": "keycloak",
  "accessTokenLifespan": 300,
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 28800,
  "registrationAllowed": true,
  "registrationEmailAsUsername": true,
  "verifyEmail": true,
  "resetPasswordAllowed": true,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "editUsernameAllowed": false,
  "passwordPolicy": "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and passwordHistory(5)",
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 5,
  "smtpServer": {
    "host": "smtp.resend.com",
    "port": "465",
    "from": "${SMTP_FROM}",
    "fromDisplayName": "${SMTP_FROM_DISPLAY_NAME}",
    "ssl": "true",
    "starttls": "false",
    "auth": "true",
    "user": "resend",
    "password": "${RESEND_API_KEY}"
  }
}
EOF
)

if [ "${REALM_STATUS}" = "200" ]; then
  echo "Realm already exists. Updating realm settings..."

  UPDATE_STATUS=$(curl -s -o /tmp/realm_update.json -w "%{http_code}" -X PUT \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${REALM_SETTINGS}")

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
    -d "${REALM_SETTINGS}")

  if [ "${CREATE_STATUS}" = "201" ]; then
    echo "Realm created."
  else
    echo "Realm creation failed (HTTP ${CREATE_STATUS}):"
    cat /tmp/realm_create.json
    exit 1
  fi
fi


# --------------------------------------------------------------------
# User events
# --------------------------------------------------------------------

echo "Enabling user events on realm: ${REALM_NAME}..."

EVENTS_STATUS=$(curl -s -o /tmp/events_update.json -w "%{http_code}" -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventsEnabled\": true,
    \"eventsExpiration\": 2592000,
    \"enabledEventTypes\": [
      \"LOGIN\",
      \"LOGIN_ERROR\",
      \"LOGOUT\",
      \"REGISTER\",
      \"REGISTER_ERROR\",
      \"CODE_TO_TOKEN\",
      \"REFRESH_TOKEN\",
      \"REFRESH_TOKEN_ERROR\"
    ]
  }")

if [ "${EVENTS_STATUS}" = "204" ]; then
  echo "User events enabled."
else
  echo "Failed to enable user events (HTTP ${EVENTS_STATUS}):"
  cat /tmp/events_update.json
fi

rm -f /tmp/events_update.json


# --------------------------------------------------------------------
# Frontend Client (public)
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


# --------------------------------------------------------------------
# Grafana Client (confidential)
# --------------------------------------------------------------------

echo "Checking for client: ${GRAFANA_CLIENT_ID}..."

EXISTING_GRAFANA_CLIENT=$(curl -sf \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${GRAFANA_CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r 'length')

if [ "${EXISTING_GRAFANA_CLIENT}" != "0" ]; then
  echo "Grafana client already exists. Skipping creation."
else
  echo "Creating Grafana client: ${GRAFANA_CLIENT_ID}..."

  CREATE_STATUS=$(curl -s -o /tmp/grafana_client_create.json -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"${GRAFANA_CLIENT_ID}\",
      \"name\": \"Grafana\",
      \"description\": \"OIDC client for Grafana SSO\",
      \"enabled\": true,
      \"publicClient\": false,
      \"secret\": \"${GF_CLIENT_SECRET}\",
      \"baseUrl\": \"${GRAFANA_URL}\",
      \"redirectUris\": [
        \"${GRAFANA_URL}/login/generic_oauth\"
      ],
      \"webOrigins\": [
        \"${GRAFANA_URL}\"
      ],
      \"standardFlowEnabled\": true,
      \"implicitFlowEnabled\": false,
      \"directAccessGrantsEnabled\": false,
      \"serviceAccountsEnabled\": false
    }")

  if [ "${CREATE_STATUS}" = "201" ]; then
    echo "Grafana client created."
  else
    echo "Grafana client creation failed (HTTP ${CREATE_STATUS}):"
    cat /tmp/grafana_client_create.json
    exit 1
  fi
fi

# --------------------------------------------------------------------
# Admin role creation (Users will be created via GUI)
# --------------------------------------------------------------------
 
echo "Creating realm role 'admin' for RBAC (Req 7)..."
 
ADMIN_ROLE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles/admin" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
 
if [ "${ADMIN_ROLE_STATUS}" = "200" ]; then
  echo "Role 'admin' already exists. Skipping."
else
  echo "Creating role: admin..."
  CREATE_ROLE_STATUS=$(curl -s -o /tmp/role_create.json -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"admin\",
      \"description\": \"WorkUp platform/infra owner — maps to Grafana Admin via role_attribute_path. Assigned manually to individual users through Keycloak Admin Console as part of onboarding, not created by this script.\"
    }")
 
  if [ "${CREATE_ROLE_STATUS}" = "201" ]; then
    echo "Role 'admin' created."
  else
    echo "Role 'admin' creation failed (HTTP ${CREATE_ROLE_STATUS}):"
    cat /tmp/role_create.json
  fi
fi
 
rm -f /tmp/role_create.json

# --------------------------------------------------------------------
# Cloudflare Access Client (confidential)
# --------------------------------------------------------------------

echo "Checking for client: ${CF_CLIENT_ID}..."

EXISTING_CF_CLIENT=$(curl -sf \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CF_CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r 'length')

if [ "${EXISTING_CF_CLIENT}" != "0" ]; then
  echo "Cloudflare Access client already exists. Skipping creation."
else
  echo "Creating Cloudflare Access client: ${CF_CLIENT_ID}..."

  CREATE_STATUS=$(curl -s -o /tmp/cf_client_create.json -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"${CF_CLIENT_ID}\",
      \"name\": \"Cloudflare Access\",
      \"description\": \"OIDC client for Cloudflare Zero Trust / Access\",
      \"enabled\": true,
      \"publicClient\": false,
      \"secret\": \"${CF_CLIENT_SECRET}\",
      \"redirectUris\": [
        \"${CLOUDFLARE_CALLBACK}\"
      ],
      \"webOrigins\": [
        \"https://${CLOUDFLARE_TEAM_NAME}.cloudflareaccess.com\"
      ],
      \"standardFlowEnabled\": true,
      \"implicitFlowEnabled\": false,
      \"directAccessGrantsEnabled\": false,
      \"serviceAccountsEnabled\": false
    }")

  if [ "${CREATE_STATUS}" = "201" ]; then
    echo "Cloudflare Access client created."
  else
    echo "Cloudflare Access client creation failed (HTTP ${CREATE_STATUS}):"
    cat /tmp/cf_client_create.json
    exit 1
  fi
fi

# --------------------------------------------------------------------
# Always print the Cloudflare client secret (even if client already existed)
# --------------------------------------------------------------------

echo
echo "Fetching Cloudflare Access client secret..."

CF_CLIENT_UUID=$(curl -sf \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CF_CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

CF_CLIENT_SECRET=$(curl -sf \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CF_CLIENT_UUID}/client-secret" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

rm -f \
  /tmp/realm_create.json \
  /tmp/realm_update.json \
  /tmp/client_create.json \
  /tmp/cf_client_create.json


# echo
# echo "============================================================"
# echo " Bootstrap complete"
# echo "============================================================"
# echo
# echo "OIDC discovery URL:"
# echo "  ${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration"
# echo
# echo "Frontend config:"
# echo "  KEYCLOAK_URL : ${KEYCLOAK_URL}"
# echo "  REALM        : ${REALM_NAME}"
# echo "  CLIENT_ID    : ${CLIENT_ID}"
# echo
# echo "Cloudflare Access (use these values in Zero Trust → Identity providers → OpenID Connect):"
# echo "  Client ID     : ${CF_CLIENT_ID}"
# echo "  Client Secret : ${CF_CLIENT_SECRET}"
# echo "  Auth URL      : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/auth"
# echo "  Token URL     : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/token"
# echo "  Certs URL     : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/certs"
# echo
# echo "Redirect URI used : ${CLOUDFLARE_CALLBACK}"
# echo "============================================================"


# echo
# echo "Grafana SSO (use these values in Grafana env / grafana.ini):"
# echo "  Client ID     : ${GRAFANA_CLIENT_ID}"
# echo "  Client Secret : ${GF_CLIENT_SECRET}"
# echo "  Auth URL      : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/auth"
# echo "  Token URL     : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/token"
# echo "  API URL       : ${AUTH_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo"
# echo "  Redirect URI  : ${GRAFANA_URL}/login/generic_oauth"