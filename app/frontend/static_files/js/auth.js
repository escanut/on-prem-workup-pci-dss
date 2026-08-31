// ── WorkUp auth (Amazon Cognito, Authorization Code + PKCE) ────────
// This is the only file that talks to Cognito. Every page that needs
// to know "is someone logged in" calls Auth.getSession() from here.
//
// Flow:
//   1. login.html  -> Auth.login()            redirects to Cognito Hosted UI
//   2. Cognito     -> redirects back to dashboard.html?code=...
//   3. dashboard.html -> Auth.handleRedirect() exchanges code for tokens
//   4. Tokens are kept in sessionStorage (cleared when the tab closes)

const Auth = (() => {
  const STORAGE_KEY = "workup_session";

  // -- PKCE helpers ----------------------------------------------------
  function base64UrlEncode(buffer) {
    return btoa(String.fromCharCode(...new Uint8Array(buffer)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  async function createPkcePair() {
    const verifierBytes = new Uint8Array(32);
    crypto.getRandomValues(verifierBytes);
    const codeVerifier = base64UrlEncode(verifierBytes);

    const digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(codeVerifier)
    );
    const codeChallenge = base64UrlEncode(digest);

    return { codeVerifier, codeChallenge };
  }

  // -- Public API --------------------------------------------------------
  async function login() {
    const { codeVerifier, codeChallenge } = await createPkcePair();
    sessionStorage.setItem("pkce_verifier", codeVerifier);

    const params = new URLSearchParams({
      client_id: CONFIG.cognito.clientId,
      response_type: "code",
      scope: CONFIG.cognito.scope,
      redirect_uri: CONFIG.cognito.redirectUri,
      code_challenge_method: "S256",
      code_challenge: codeChallenge,
    });

    window.location.href = `${CONFIG.cognito.domain}/oauth2/authorize?${params}`;
  }

  function logout() {
    sessionStorage.removeItem(STORAGE_KEY);
    const params = new URLSearchParams({
      client_id: CONFIG.cognito.clientId,
      logout_uri: CONFIG.cognito.logoutRedirectUri,
    });
    window.location.href = `${CONFIG.cognito.domain}/logout?${params}`;
  }

  // Called once on dashboard.html load to catch the ?code=... redirect
  async function handleRedirect() {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");
    if (!code) return getSession(); // no code in URL, just check existing session

    const codeVerifier = sessionStorage.getItem("pkce_verifier");
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: CONFIG.cognito.clientId,
      code,
      redirect_uri: CONFIG.cognito.redirectUri,
      code_verifier: codeVerifier,
    });

    const res = await fetch(`${CONFIG.cognito.domain}/oauth2/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });

    if (!res.ok) {
      console.error("Token exchange failed", await res.text());
      return null;
    }

    const tokens = await res.json(); // { id_token, access_token, refresh_token, expires_in }
    const session = {
      idToken: tokens.id_token,
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      expiresAt: Date.now() + tokens.expires_in * 1000,
    };
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));

    // clean the ?code=... out of the URL bar
    window.history.replaceState({}, document.title, window.location.pathname);
    return session;
  }

  function getSession() {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    if (Date.now() >= session.expiresAt) {
      sessionStorage.removeItem(STORAGE_KEY);
      return null;
    }
    return session;
  }

  // Call this at the top of any protected page (e.g. dashboard.html, billing.html)
  function requireAuth() {
    const session = getSession();
    if (!session) {
      window.location.href = "login.html";
    }
    return session;
  }

  return { login, logout, handleRedirect, getSession, requireAuth };
})();
