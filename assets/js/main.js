/* SolyntraAI — Global UI behaviors (Vanilla JS) */

function updateNav() {
  const isLoggedIn = localStorage.getItem("sb_user") !== null; // temp check
  document.querySelector(".nav-public")?.classList.toggle("hidden", isLoggedIn);
  document.querySelector(".nav-app")?.classList.toggle("hidden", !isLoggedIn);
}

function showToast(message, type = "success") {
  const toast = document.createElement("div");
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.classList.add("show"), 10);
  setTimeout(() => {
    toast.classList.remove("show");
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

function init3DTilt() {
  document.querySelectorAll(".card-3d").forEach((card) => {
    card.addEventListener("mousemove", (e) => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;
      card.style.transform = `perspective(1000px) rotateY(${x * 10}deg) rotateX(${-y * 10}deg) translateZ(10px)`;
    });
    card.addEventListener("mouseleave", () => {
      card.style.transform = "perspective(1000px) rotateY(0) rotateX(0) translateZ(0)";
    });
  });
}

function initMobileMenu() {
  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelector(".nav-links");

  if (!toggle || !links) return;

  const close = () => document.body.classList.remove("nav-open");
  const open = () => document.body.classList.add("nav-open");
  const isOpen = () => document.body.classList.contains("nav-open");

  toggle.addEventListener("click", () => (isOpen() ? close() : open()));

  links.addEventListener("click", (e) => {
    const a = e.target.closest("a");
    if (a) close();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") close();
  });

  window.addEventListener("resize", () => {
    if (window.innerWidth >= 768) close();
  });
}

function initFloatingCTA() {
  const floatingCTA = document.querySelector(".floating-cta");
  if (!floatingCTA) return;

  floatingCTA.addEventListener("click", () => {
    const starterLink = document.querySelector('[data-plan="starter"]');
    if (starterLink && starterLink.getAttribute("href")) {
      window.location.href = starterLink.getAttribute("href");
      return;
    }
    window.location.href = "https://www.paypal.com/ncp/payment/3UYP578XT4AE6";
  });
}

function initQrModal() {
  const qrTrigger = document.querySelector("#qr-trigger");
  const modal = document.querySelector("#qr-modal");
  const modalClose = document.querySelector("#qr-modal .modal-close");
  if (!modal) return;

  qrTrigger?.addEventListener("click", () => modal.classList.add("active"));
  modalClose?.addEventListener("click", () => modal.classList.remove("active"));

  modal.addEventListener("click", (e) => {
    if (e.target === modal) modal.classList.remove("active");
  });
}

document.addEventListener("DOMContentLoaded", () => {
  updateNav();
  initMobileMenu();
  init3DTilt();
  initFloatingCTA();
  initQrModal();
});

window.Solyntra = {
  showToast,
  updateNav,
};
