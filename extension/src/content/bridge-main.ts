// Runs in MAIN world on FyxxVault domains — has direct access to localStorage.
// Reads Supabase session and sends it to the ISOLATED world bridge via postMessage.

const SUPABASE_STORAGE_KEY = 'sb-oqcmbgtpqjzfscymnije-auth-token';
const ALLOWED_ORIGINS = ['https://fyxxvault.com', 'https://www.fyxxvault.com'];

function getTargetOrigin(): string {
  if (ALLOWED_ORIGINS.includes(window.location.origin)) {
    return window.location.origin;
  }
  // localhost dev
  if (window.location.hostname === 'localhost') {
    return window.location.origin;
  }
  return window.location.origin;
}

function sendSession() {
  try {
    const raw = localStorage.getItem(SUPABASE_STORAGE_KEY);
    if (raw) {
      window.postMessage({ type: '__FYXX_SESSION__', payload: raw }, getTargetOrigin());
    }
  } catch {}
}

// Send session on load
sendSession();

// Re-send when page regains focus
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') sendSession();
});

// Re-send periodically (session refresh)
setInterval(sendSession, 30000);
