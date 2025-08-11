/* Main JavaScript for Lumora static site */

document.addEventListener('DOMContentLoaded', () => {
  // Floating CTA click navigates to Starter plan link if present
  const floatingCTA = document.querySelector('.floating-cta');
  if (floatingCTA) {
    floatingCTA.addEventListener('click', (e) => {
      // Try to find a starter plan anchor on the page
      const starterLink = document.querySelector('[data-plan="starter"]');
      if (starterLink && starterLink.getAttribute('href')) {
        window.location.href = starterLink.getAttribute('href');
      } else {
        // Fallback: direct to the hosted Starter plan PayPal link
        window.location.href = 'https://www.paypal.com/ncp/payment/3UYP578XT4AE6';
      }
    });
  }

  // Pay by QR modal
  const qrTrigger = document.querySelector('#qr-trigger');
  const modal = document.querySelector('#qr-modal');
  const modalClose = document.querySelector('#qr-modal .modal-close');
  if (qrTrigger && modal) {
    qrTrigger.addEventListener('click', () => {
      modal.classList.add('active');
    });
  }
  if (modalClose && modal) {
    modalClose.addEventListener('click', () => {
      modal.classList.remove('active');
    });
  }

  // Close modal when clicking outside content
  if (modal) {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.classList.remove('active');
      }
    });
  }
});
