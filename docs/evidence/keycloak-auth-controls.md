# Keycloak Authentication & Access Controls

**PCI DSS references:** Requirement 7 (access by business need to know), Requirement 8 (identify users and authenticate access)  
**Scope:** WorkUp SAQ A-EP lab  
**System:** Keycloak realm `workup` on the Auth VM (`auth.victorojeje.xyz`)  
**Last reviewed:** 2026-09-23  
**Owner:** Platform operator (solo lab)

This note records what was configured and why. It is supporting evidence for the SAQ, not a formal policy manual.

---

## 1. Realm authentication settings (Req 8)

Configured in the realm via the bootstrap script so create and update paths stay consistent.

| Setting | Value | Reason |
|---------|-------|--------|
| Password policy | length(12) + upper + lower + digit + special + notUsername + history(5) | Meets PCI DSS 8.3.6 complexity expectations |
| verifyEmail | true | Account is only fully usable after the email address is proven. Reduces fake/spam registrations and improves password-reset reliability |
| Email delivery | Resend (SMTP) | Transactional email for verification and password reset. Custom domain, TLS, API-key auth |
| Brute-force protection | Enabled (failureFactor 5, max wait 900s, temporary lockout) | Limits credential-guessing attacks |
| accessTokenLifespan | 300 seconds (5 min) | Short-lived tokens |
| ssoSessionIdleTimeout | 1800 seconds (30 min) | Idle session limit |
| ssoSessionMaxLifespan | 28800 seconds (8 h) | Hard upper bound on session lifetime |
| loginWithEmailAllowed | true | Users sign in with email |
| registrationEmailAsUsername | true | Email is the username |
| duplicateEmailsAllowed | false | One account per email |
| editUsernameAllowed | false | Username (email) cannot be changed after registration |
| resetPasswordAllowed | true | Self-service password reset |

Self-registration remains enabled. This is a deliberate product decision for a self-serve SaaS lab. New accounts receive no elevated realm role by default.

---

## 2. Access control model (Req 7)

### What Keycloak actually gates

Only two systems authenticate through this realm:

- WorkUp frontend (public client, PKCE)
- Grafana (confidential client, OIDC)

Other systems (Stripe dashboard, GitLab, Proxmox, SSH) are outside this realm and are controlled by their own access mechanisms.

### Realm role (implemented)

| Role | Purpose | How it is used |
|------|---------|----------------|
| `admin` | Platform / infra owner | Mapped in Grafana via `role_attribute_path`. Users without this role are denied Grafana login (strict mode). |

The `admin` realm role is unrelated to the Keycloak master admin account. It is a label inside the `workup` realm only. It does not grant access to the Keycloak Admin Console.

No other realm roles are defined. Customer self-registered accounts receive no elevated role by default.

Access to systems outside this realm (Stripe dashboard, GitLab, Proxmox, SSH) is handled by those systems' own controls and is not claimed as Keycloak-enforced evidence here.

---

## 3. Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `workup-frontend` | Public + PKCE (S256) | Browser login for the application |
| `grafana` | Confidential | Grafana SSO |
| `cloudflare-access` | Confidential | Cloudflare Zero Trust OIDC IdP |

Standard flow only. Direct access grants disabled on these clients.

---

## 4. MFA / OTP (Req 8.3 / 8.4)

**Implemented 2026-09-23.**

| Control | Implementation | Notes |
|---------|----------------|-------|
| Keycloak OTP (TOTP) | Enabled for privileged / administrative access paths in the `workup` realm | Users with elevated access configure a TOTP authenticator (e.g. authenticator app). Required for non-console administrative actions where Keycloak is in the path. |
| Cloudflare Access OTP | Backup / emergency login method | One-time PIN offered by Cloudflare Access when Keycloak is unavailable or for emergency admin access. |
| SSH | Key-only; no password auth | Management-network restricted. Does not rely on Keycloak OTP for console access. |

**MFA posture for non-console admin access to payment-page-adjacent systems:**
- SSH key-only + management-network restriction (Proxmox / ufw)
- Keycloak OTP for identity-provider and application admin paths
- Cloudflare Access OTP as emergency backup

This satisfies the intent of Req 8.4 (MFA for non-console access into the CDE / payment-page environment) for the lab scope. Full mandatory MFA for every end-user customer account is not required by SAQ A-EP for this architecture and is not claimed.

---

## 5. What is intentionally not present

- No shared or generic interactive user accounts for people.
- No password authentication for SSH (key-only, management network restricted).
- No backend API role checks yet. Current API routes only distinguish authenticated vs unauthenticated. Role-based route gating will be added if admin-only API endpoints are introduced.
- Mandatory OTP for every self-registered customer account is not enforced (product decision for a self-serve SaaS lab). OTP is required for privileged/admin paths.

---

## 6. Operational notes

- Individual human accounts and the `admin` role assignment are done in the Keycloak Admin Console as people are onboarded. The bootstrap script creates the role definition only; it does not create users.
- SMTP settings for verification and password-reset email are applied by the same bootstrap script (Resend).
- Realm events (LOGIN, LOGIN_ERROR, LOGOUT, REGISTER, etc.) are enabled for audit visibility.
- OTP configuration for privileged users is performed in the Keycloak Admin Console (or user account console) after the account is created.

This configuration is intended to show that authentication and access controls were set deliberately to match the system’s actual trust boundaries and the SAQ A-EP scope.
