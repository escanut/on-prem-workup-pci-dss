# AIDE — File Integrity Monitoring (Req 11.5.2)

**PCI DSS reference:** Requirement 11.5.2 (change-detection mechanism on critical files)  
**Scope:** WorkUp SAQ A-EP lab  
**System:** AIDE on the four segmented Ubuntu 22.04 VMs  
**Last reviewed:** 2026-09-23  
**Owner:** Platform operator (solo lab)

This note records the lightweight file integrity monitoring control used to meet the intent of PCI DSS 11.5.2 for the payment-page environment and supporting system components. It is supporting evidence for the SAQ, not a formal policy manual.

---

## 1. Why AIDE

SAQ A-EP Requirement 11.5.2 requires a change-detection mechanism that:

- Alerts personnel to unauthorized modification (changes, additions, deletions) of critical files
- Performs critical file comparisons at least once weekly

AIDE (Advanced Intrusion Detection Environment) was chosen because it is:

- Open source, well-known, and suitable for a headless Linux server lab
- Lightweight (no commercial FIM agent required)
- Able to produce clear reports that can be shipped to journald / Loki for visibility

---

## 2. Scope of monitored files (critical files)

Critical files are defined as those that, if modified without authorization, could indicate compromise or risk to the payment page / CDE-adjacent systems. The following categories are included on each relevant VM:

| Category | Examples | VMs |
|----------|----------|-----|
| Host OS security config | `/etc/ssh/sshd_config`, `/etc/sudoers*`, `/etc/sysctl.conf`, `/etc/ufw/*`, `/etc/security/limits.conf` | All four |
| Network / firewall | ufw rules, relevant systemd unit files | All four |
| Payment-page assets | `billing.html`, first-party JS under the frontend static path (`config.js`, `billing.js`, etc.) | Frontend |
| Application compose / runtime | Docker Compose files, env templates that affect the payment flow (excluding secrets themselves) | Frontend, Auth, Backend |
| Auth configuration | Keycloak realm-related config paths that affect authentication (non-secret) | Auth |
| Logging / monitoring | Alloy / Prometheus / Loki config that affects audit visibility | Observability (+ others where Alloy runs) |

Secrets (API keys, tunnel tokens, database passwords) are **not** stored in AIDE-monitored plain-text paths; they live in environment / secret management and are outside the FIM baseline.

---

## 3. Operational process

1. **Baseline**  
   AIDE database is initialized after a known-good configuration state (post-hardening, post-deploy of payment-page assets).

2. **Scheduled check**  
   AIDE is run at least weekly (cron or systemd timer). Report is written to a predictable location and/or journald so it can be picked up by Alloy → Loki.

3. **Review**  
   Unexpected changes are investigated. Expected changes (legitimate deploys, intentional config updates) are accepted by re-initializing or updating the AIDE database after the change is approved.

4. **Alerting**  
   In the lab, reports are visible in Loki/Grafana. Production would add explicit alerting (e.g. on non-zero exit / unexpected diff).

---

## 4. Relationship to other controls

| Control | How it complements AIDE |
|---------|-------------------------|
| **11.6.1 / 6.4.3** (payment-page scripts) | Client-side script inventory and integrity process for scripts delivered to the browser. AIDE covers the server-side files that serve those scripts. |
| **6.5** (change control) | Legitimate changes should go through change process; AIDE detects unapproved drift. |
| **10.x** (logging) | AIDE reports feed the same observability stack (Loki) used for audit log review. |
| GitLab CI + Git | Source-of-truth for application code; AIDE is the runtime host/file-system check. |

---

## 5. Lab limitations (explicit)

- This is a portfolio lab, not a production PCI assessment. AIDE configuration and coverage are sized to demonstrate the control, not to claim enterprise FIM completeness.
- No commercial FIM product (e.g. Tripwire, OSSEC enterprise) is used.
- Baseline and check frequency are documented here; evidence of a specific weekly run is produced when the VMs are up and the timer has fired.
- If project scope expands (more interactive workloads, more critical binaries), the AIDE ruleset will be expanded accordingly.

---

## 6. Status

| Item | Status |
|------|--------|
| AIDE installed and baseline initialized | **Done** (2026-09-23) |
| Critical file rules defined for payment-page + host hardening paths | **Done** |
| Weekly (or better) check scheduled | **Done** |
| Reports available for review (journal/Loki) | **Done** / visible in observability stack |
| Supporting note for SAQ | This document |

**SAQ response guidance:** Mark **11.5.2** as **In Place**. Reference this note and the AIDE configuration/evidence on the VMs.
