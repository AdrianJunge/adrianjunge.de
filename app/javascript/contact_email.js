function initializeContactEmails() {
  document.querySelectorAll('[data-contact-email]').forEach(link => {
    const address = window.atob(link.dataset.contactEmail);
    link.href = `mailto:${address}`;
    link.title = address;
    link.hidden = false;
  });
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeContactEmails, { once: true });
else initializeContactEmails();
