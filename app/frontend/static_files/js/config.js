
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
    publishableKey: "pk_test_51R6GJCEFe2s2FXuqhskQXTkGhFufwTvm2Jdf6DQMWVbrZ9cmG4zd4JQxLEjsKX4skbCQhkbxl1nsBcN1AOvFGlNA00zGeuqV9j", // safe to expose client-side
  },

  // FastAPI backend (api.workup.com per the architecture doc)
  api: {
    baseUrl: "https://api.victorojeje.xyz",
  },
};
