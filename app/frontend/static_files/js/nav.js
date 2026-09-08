// ── Shared nav behavior for protected pages ─────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  const logoutBtn = document.getElementById("logout-btn");
  if (logoutBtn) {
    logoutBtn.addEventListener("click", () => Auth.logout());
  }
});
