// ── WorkUp frontend config ──────────────────────────────────────────
// Single source of truth. Replace these values with your real
// Cognito User Pool + App Client + Stripe details before deploying.
// Nothing else in the codebase should hardcode these values.

const CONFIG = {
  // AWS Cognito
  cognito: {
    domain: "https://workup-auth.auth.us-east-1.amazoncognito.com", // Cognito Hosted UI domain
    clientId: "REPLACE_WITH_APP_CLIENT_ID",                          // App client ID (public client, no secret)
    redirectUri: "https://www.workup.com/dashboard.html",            // Must be in Cognito's allowed callback URLs
    logoutRedirectUri: "https://www.workup.com/index.html",          // Must be in Cognito's allowed sign-out URLs
    scope: "openid email profile",
  },

  // Stripe
  stripe: {
    publishableKey: "pk_test_REPLACE_WITH_PUBLISHABLE_KEY", // safe to expose client-side
  },

  // FastAPI backend (api.workup.com per the architecture doc)
  api: {
    baseUrl: "https://api.workup.com",
  },
};
