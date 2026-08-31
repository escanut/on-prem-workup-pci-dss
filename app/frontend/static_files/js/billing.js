// ── WorkUp billing (Stripe Embedded Checkout) ───────────────────────
// One subscription tier, one price ID, no plan-picker logic needed.
// The "popup" is Stripe's Embedded Checkout mounted inside a modal
// that overlays the page — the customer never leaves workup.com and
// card data never touches our frontend or backend, only Stripe's
// hosted iframe. This is what keeps the project inside SAQ A-EP scope.

document.addEventListener("DOMContentLoaded", () => {
  const session = Auth.requireAuth();
  if (!session) return;

  const stripe = Stripe(CONFIG.stripe.publishableKey);
  const subscribeBtn = document.getElementById("subscribe-btn");
  const modal = document.getElementById("checkout-modal");
  const closeBtn = document.getElementById("checkout-close");
  const checkoutContainer = document.getElementById("checkout-container");

  let embeddedCheckout = null;

  async function openCheckout() {
    modal.classList.add("open");
    document.body.style.overflow = "hidden";

    // Backend creates the Checkout Session (ui_mode: "embedded") and
    // returns its client_secret. See WRITEUP.md for the FastAPI route.
    const fetchClientSecret = async () => {
      const res = await fetch(`${CONFIG.api.baseUrl}/billing/create-checkout-session`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session.idToken}`,
        },
      });
      if (!res.ok) throw new Error("Could not start checkout");
      const data = await res.json();
      return data.client_secret;
    };

    embeddedCheckout = await stripe.initEmbeddedCheckout({ fetchClientSecret });
    embeddedCheckout.mount("#checkout-container");
  }

  function closeCheckout() {
    if (embeddedCheckout) {
      embeddedCheckout.destroy();
      embeddedCheckout = null;
    }
    checkoutContainer.innerHTML = "";
    modal.classList.remove("open");
    document.body.style.overflow = "";
  }

  subscribeBtn.addEventListener("click", openCheckout);
  closeBtn.addEventListener("click", closeCheckout);
  modal.addEventListener("click", (e) => {
    if (e.target === modal) closeCheckout(); // click on the dark overlay closes it
  });
});
