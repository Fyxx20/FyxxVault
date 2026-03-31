// Content script that runs on FyxxVault web app domains.
// Automatically reads Supabase session from localStorage and sends it to the extension.
// Also listens for VEK events when the user unlocks the vault on the web app.

const SUPABASE_STORAGE_KEY = 'sb-oqcmbgtpqjzfscymnije-auth-token';

// ─── Auto-read session from localStorage ───
// Content scripts can't access page localStorage directly (isolated world).
// We inject a tiny script into the page context to read it.
function readSessionFromPage() {
  const script = document.createElement('script');
  script.textContent = `
    (function() {
      try {
        const raw = localStorage.getItem('${SUPABASE_STORAGE_KEY}');
        if (raw) {
          window.postMessage({ type: '__FYXX_SESSION__', payload: raw }, '*');
        }
      } catch(e) {}
    })();
  `;
  document.documentElement.appendChild(script);
  script.remove();
}

// Listen for the session data from the injected script
window.addEventListener('message', (e) => {
  if (e.source !== window) return;

  if (e.data?.type === '__FYXX_SESSION__') {
    try {
      const session = JSON.parse(e.data.payload);
      if (session?.access_token && session?.refresh_token) {
        chrome.runtime.sendMessage({
          type: 'BRIDGE_SESSION',
          session: {
            access_token: session.access_token,
            refresh_token: session.refresh_token
          }
        });
      }
    } catch {}
  }

  if (e.data?.type === '__FYXX_VEK__') {
    chrome.runtime.sendMessage({
      type: 'BRIDGE_VEK',
      vekHex: e.data.payload
    });
  }
});

// Listen for custom events dispatched by the web app (when vault is unlocked)
window.addEventListener('fyxxvault-bridge-session', ((e: CustomEvent) => {
  chrome.runtime.sendMessage({
    type: 'BRIDGE_SESSION',
    session: e.detail
  });
}) as EventListener);

window.addEventListener('fyxxvault-bridge-vek', ((e: CustomEvent) => {
  chrome.runtime.sendMessage({
    type: 'BRIDGE_VEK',
    vekHex: e.detail
  });
}) as EventListener);

// Read session immediately on page load
readSessionFromPage();

// Also re-read when the page regains focus (user might have logged in on another tab)
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    readSessionFromPage();
  }
});

// Tell the web app the extension is ready (so it can send the VEK if already unlocked)
window.dispatchEvent(new CustomEvent('fyxxvault-extension-ready'));
