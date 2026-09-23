# Payment Page Script Inventory & Change Detection

**PCI DSS references:** 6.4.3 (script management on payment pages), 11.6.1 (change- and tamper-detection on payment pages)  
**Scope:** WorkUp SAQ A-EP, merchant-hosted payment page that loads Stripe Embedded Checkout  
**Page in scope:** `billing.html` (Frontend VM → `https://victorojeje.xyz` / `www.victorojeje.xyz`)  
**Last reviewed:** 2026-09-23  
**Owner:** Platform operator (solo lab)

---

## 1. Script inventory (6.4.3)

All scripts loaded by the payment page, confirmed by review of  
`app/frontend/static_files/billing.html` and the referenced first-party JS files.

| # | Script | Origin | First / third party | Business / technical justification | Authorization | Integrity method |
|---|--------|--------|---------------------|------------------------------------|---------------|------------------|
| 1 | `/js/config.js` | WorkUp frontend static assets | First-party | Non-secret runtime config (API base URL, Stripe publishable key). Required by billing.js and auth helpers. | Shipped in application repo; deployed only via Ansible + Docker Compose | SHA-256 hash recorded at each deploy (see §3) |
| 2 | `/js/auth.js` | WorkUp frontend static assets | First-party | Session check / logout helpers so only authenticated users reach checkout | Same as above | SHA-256 at deploy |
| 3 | `/js/nav.js` | WorkUp frontend static assets | First-party | Navigation and logout UI on the billing page | Same as above | SHA-256 at deploy |
| 4 | `https://js.stripe.com/v3/` | Stripe | Third-party | Official Stripe.js SDK for **Embedded Checkout**. Card data is entered only inside Stripe-controlled UI; PAN/SAD never touch WorkUp systems. | Stripe is the PCI DSS Level 1 TPSP for payment processing; this SDK is required for the chosen integration model | **SRI not supported** by Stripe.js (content changes for fraud/detection updates). Compensating control: Stripe’s PCI Level 1 status and AOC. See §2. |
| 5 | `/js/billing.js` | WorkUp frontend static assets | First-party | Calls backend `POST /billing/create-checkout-session`, then `stripe.initEmbeddedCheckout()` and mounts the checkout UI | Same as first-party assets | SHA-256 at deploy |

### Scripts explicitly not present

- No analytics, chat widgets, A/B testing, marketing pixels, or tag managers on `billing.html`.
- `billing.js` does not dynamically inject additional `<script>` tags; it only calls the already-loaded Stripe.js API.

### Related pages (out of scope for 6.4.3 / 11.6.1)

`index.html`, `login.html`, and `dashboard.html` load subsets of the first-party scripts above but do **not** load Stripe.js and do not collect or influence account data entry. They are noted only for completeness.

---

## 2. Integrity notes (6.4.3)

### First-party scripts

Integrity is maintained by:

1. Source of truth in the Git repository (`app/frontend/static_files/`).
2. Deployment only through the controlled Ansible + Docker Compose path (no ad-hoc edits on the VM).
3. Per-deploy (and at least weekly) comparison of file hashes against the inventory baseline (see §3).

### Stripe.js (`https://js.stripe.com/v3/`)

Stripe does not publish stable Subresource Integrity (SRI) hashes for this endpoint because the script is updated frequently for fraud and abuse detection.

**Compensating controls:**

- Stripe is a PCI DSS Level 1 Service Provider; the merchant relies on Stripe’s AOC for the security of the SDK and of Embedded Checkout.
- WorkUp never receives PAN/SAD (confirmed under Requirements 3 and 4).
- Only the official `https://js.stripe.com/v3/` endpoint is used (no third-party mirrors or forks).

---

## 3. Change- and tamper-detection procedure (11.6.1)

**Objective:** Detect unauthorized modification of the payment page HTTP response and of the scripts listed in §1, as received by the consumer browser.

### Frequency

- At every production deployment of the frontend stack, **and**
- At least once every seven days if no deploy occurred that week.

(Lab default = weekly check + mandatory check on deploy. A formal targeted risk analysis under 12.3.1 may later justify a different period; until then weekly is used.)

### Method (lab-appropriate)

1. **Baseline**  
   After any approved change to `billing.html` or `js/{config,auth,nav,billing}.js`, record SHA-256 hashes of those files and store them with this inventory (or in the deploy log).

2. **Weekly / pre-deploy check**  
   - Fetch the live payment page: `https://victorojeje.xyz/billing.html` (and `www` if served separately).  
   - Confirm the `<script src=...>` list still matches §1 exactly (no added or removed scripts; Stripe URL unchanged).  
   - Recompute SHA-256 of the four first-party JS files on the Frontend VM (or from the release artifact) and compare to baseline.  
   - Optionally note security-relevant response headers for unexpected change.

3. **Alert / response**  
   Any mismatch is treated as a security event:  
   - Do not ignore.  
   - Preserve evidence (hashes, page snapshot, deploy revision).  
   - Investigate (unauthorized change vs forgotten inventory update).  
   - Remediate and update the baseline only after an intentional, authorized change.

4. **Record**  
   Note date, result (match / mismatch), and operator in a simple log kept alongside this inventory.

### What this does not require in the lab

- No commercial client-side skimming detection product.
- No continuous browser-based agent.
- No SRI on Stripe.js (vendor limitation, documented above).

---

## 4. Approval

| Role | Name / notes | Date |
|------|--------------|------|
| Inventory author | Platform operator | 2026-09-15 |
| Last review | Platform operator | 2026-09-23 |

Unauthorized scripts must not be added to the payment page. Any new script requires an update to this inventory and a new baseline **before** production deploy.
