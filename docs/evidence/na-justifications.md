# N/A Justifications

**Project:** WorkUp, PCI DSS SAQ A-EP (lab / portfolio)  
**Last updated:** 2026-09-23  
**Purpose:** Short, evidence-based justifications for requirements marked Not Applicable.  
**Tone:** Infrastructure controls and architecture decisions only. Not a formal policy library.

These justifications support the corresponding SAQ A-EP responses. They are based on the actual system design and code review, not assumptions.

---

## Requirement 3: Protect Stored Account Data

### 3.3 – 3.7 (SAD storage, PAN masking, encryption, key management)

**Status:** N/A

**Justification:**  
No cardholder data (PAN, SAD, or any account data) is stored on any WorkUp system.

- Payment collection uses **Stripe Embedded Checkout**.
- Card data is entered only inside Stripe-controlled UI.
- The WorkUp frontend, nginx, Go backend, and databases never receive PAN, expiry, CVV, or track data.
- Backend schema (`app/backend/db/schema.sql`) stores only Stripe identifiers (`stripe_customer_id`, `stripe_subscription_id`, `status`). No PAN-adjacent fields exist (not even last4).
- Webhook handler processes Stripe events and does not log or persist raw payment payloads containing account data.

Because no account data is stored, the storage, masking, encryption, and key-management controls in 3.3–3.7 have no applicable data to protect.

**Evidence:** Code review of `billing.js`, `billing.go`, and `schema.sql`.

---

### 3.1 / 3.2.1 (Data protection & retention policies)

**Status:** Addressed by architecture + short statement

WorkUp does not store PAN/SAD. The only payment-related records retained are Stripe customer and subscription IDs, which are not account data under PCI DSS. Retention of those identifiers follows normal business/operational needs; there is no CHD retention or disposal process to define.

---

## Requirement 4: Protect Cardholder Data with Strong Cryptography During Transmission

### 4.2.1 (Strong cryptography during transmission over open / public networks)

**Status:** N/A for CHD transmission (no CHD is transmitted by WorkUp)

**Justification:**  
WorkUp systems never transmit cardholder data.

- All payment card entry occurs inside Stripe Embedded Checkout (Stripe’s environment).
- WorkUp backends receive only Stripe tokens / event notifications, never PAN/SAD.
- Public-facing TLS is terminated at Cloudflare. Internal service traffic stays on the Compose network or management network and does not carry CHD.

Because no CHD is sent over open or public networks by the merchant, the transmission-protection requirements for cardholder data do not apply to WorkUp systems.

**Note:** TLS is still used for all public endpoints (Cloudflare) as standard security practice; this N/A applies specifically to CHD transmission.

---

## Requirement 5: Protect All Systems and Networks from Malicious Software

### 5.1 (Anti-malware / anti-virus controls)

**Status:** N/A with documented justification

**Justification:**  
Traditional signature-based anti-malware (e.g. ClamAV) is not implemented on the four VMs.

Reasoning:

- Hosts are headless Ubuntu 22.04 servers running only containerized workloads.
- There is no general-purpose user interactive desktop, no email client, no file-upload path for end users, and no office-document workflow.
- The primary attack surface is the exposed web/application layer and the container images themselves, not classic file-based malware on a general-purpose endpoint.
- Container image vulnerability scanning is performed in GitLab CI (SAST, Dependency Scanning, Container Scanning). This addresses a more relevant risk for this architecture than host AV signatures.

**Accepted residual risk:**  
No runtime host anti-malware agent. If project scope expands to include user file handling or interactive workloads, this decision will be revisited (e.g. toward runtime detection such as Falco).

This is a deliberate, architecture-based decision, not an oversight.

---

## Requirement 9: Restrict Physical Access to Cardholder Data

### Entire requirement (9.2 – 9.4)

**Status:** N/A

**Justification:**  
No cardholder data exists anywhere in the environment, electronic or paper.

- Confirmed under Requirements 3 and 4: Stripe Embedded Checkout is used; PAN/SAD never transit or are stored on any WorkUp system.
- There are therefore no systems that contain cardholder data, no paper media with account data, and no physical media requiring the controls in 9.2 or 9.4.
- 9.4.x is scoped by SAQ A-EP to merchants that possess paper records with account data. None exist.
- Facility-entry controls aimed at protecting CDE systems that hold CHD do not apply when no such data is present.

This is the same architectural fact used for the storage and transmission N/As above.

---

## Summary table

| Requirement | Status | One-line reason |
|-------------|--------|------------------|
| 3.3 – 3.7 | N/A | No CHD stored |
| 4.2.1 (CHD transmission) | N/A | No CHD transmitted by WorkUp |
| 5.1 | N/A (justified) | Headless container-only hosts; traditional AV low value |
| 9 (all) | N/A | No CHD exists (electronic or paper) |

These justifications are intended to be referenced directly when completing the corresponding SAQ A-EP questions.
