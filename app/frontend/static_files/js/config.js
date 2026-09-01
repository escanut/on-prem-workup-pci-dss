
const CONFIG = {
  keycloak: {
    domain: "https://auth.victorojeje.xyz/realms/workup",
    clientId: "workup-frontend",                          
    redirectUri: "https://www.victorojeje.xyz/dashboard.html",            
    logoutRedirectUri: "https://www.victorojeje.xyz/index.html",          
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
