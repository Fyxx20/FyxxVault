// Runs in ISOLATED world on FyxxVault domains.
// Receives session from bridge-main.ts (MAIN world) via postMessage, forwards to service worker.
// Also receives VEK from the web app via custom events and postMessage.

const TRUSTED_ORIGINS = ['https://fyxxvault.com', 'https://www.fyxxvault.com'];

function isTrustedOrigin(origin: string): boolean {
  if (TRUSTED_ORIGINS.includes(origin)) return true;
  // Allow localhost for development
  try {
    const url = new URL(origin);
    if (url.hostname === 'localhost') return true;
  } catch {}
  return false;
}

window.addEventListener('message', (e) => {
  if (e.source !== window) return;
  if (!isTrustedOrigin(e.origin)) return;

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
    if (typeof e.data.payload === 'string' && /^[0-9a-f]{64}$/i.test(e.data.payload)) {
      chrome.runtime.sendMessage({
        type: 'BRIDGE_VEK',
        vekHex: e.data.payload
      });
    }
  }
});

// Listen for custom events from the web app (when vault is unlocked)
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

// Tell the web app the extension is ready
window.dispatchEvent(new CustomEvent('fyxxvault-extension-ready'));
