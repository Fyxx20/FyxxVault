// FyxxVault Extension — Service Worker (Manifest V3)
// Manages: Supabase session, VEK in memory, vault entries cache, messaging

import { supabase } from '../shared/supabase';
import { decryptEntry, encryptEntry, decodeSupabaseBytes, encodeToSupabaseBytes, deriveKEK, unwrapVEK, hexToBytes, bytesToHex } from '../shared/crypto';
import { newVaultEntry } from '../shared/types';
import { generateTOTP } from '../shared/totp';
import type { VaultEntry, ExtMessage, ExtStatus } from '../shared/types';

// ─── Disable Chrome's built-in password manager ───
function disableChromePasswordManager() {
  chrome.privacy.services.passwordSavingEnabled.set({ value: false }, () => {
    if (chrome.runtime.lastError) {
      console.error('Failed to disable passwordSaving:', chrome.runtime.lastError);
    } else {
      console.log('FyxxVault: Chrome password saving disabled');
    }
  });
  chrome.privacy.services.autofillAddressEnabled.set({ value: false });
  chrome.privacy.services.autofillCreditCardEnabled.set({ value: false });
}

// Run on every SW wake
disableChromePasswordManager();

// ─── On install: open FyxxVault login page + disable Chrome passwords ───
chrome.runtime.onInstalled.addListener((details) => {
  disableChromePasswordManager();
  if (details.reason === 'install') {
    chrome.tabs.create({ url: chrome.runtime.getURL('onboarding/onboarding.html') });
  }
});

// ─── In-memory state ───
let vek: Uint8Array | null = null;
let entries: VaultEntry[] = [];
let lastActivity = Date.now();

// ─── Persist VEK in session storage (survives SW restarts, cleared on browser close) ───
async function persistVEK(vekBytes: Uint8Array) {
  vek = vekBytes;
  lastActivity = Date.now();
  await chrome.storage.session.set({
    vekHex: bytesToHex(vekBytes),
    vekTimestamp: Date.now()
  });
}

async function restoreVEK(): Promise<boolean> {
  if (vek) return true; // Already in memory
  try {
    const { vekHex, vekTimestamp } = await chrome.storage.session.get(['vekHex', 'vekTimestamp']);
    if (vekHex) {
      vek = hexToBytes(vekHex);
      lastActivity = vekTimestamp || Date.now();
      return true;
    }
  } catch {}
  return false;
}

function lock() {
  vek = null;
  entries = [];
  chrome.storage.session.remove(['vekHex', 'vekTimestamp']);
  chrome.action.setBadgeText({ text: '' });
}

// ─── Restore VEK on service worker wake ───
restoreVEK().then(async (restored) => {
  if (restored) {
    await loadEntries();
  }
});

// ─── Restore session on SW wake ───
async function ensureSession(): Promise<boolean> {
  const { data: { session } } = await supabase.auth.getSession();
  return !!session;
}

// ─── Load and decrypt vault entries ───
async function loadEntries(): Promise<void> {
  if (!vek) return;

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return;

  const { data, error } = await supabase
    .from('vault_items')
    .select('id, user_id, encrypted_blob, updated_at, deleted_at')
    .eq('user_id', session.user.id)
    .is('deleted_at', null)
    .order('updated_at', { ascending: false });

  if (error || !data) {
    console.error('Failed to load vault items:', error);
    return;
  }

  const decrypted: VaultEntry[] = [];
  for (const row of data) {
    try {
      const blob = decodeSupabaseBytes(row.encrypted_blob);
      const entry = await decryptEntry(blob, vek);
      entry.id = row.id;
      decrypted.push(entry);
    } catch (e) {
      console.error(`Failed to decrypt entry ${row.id}:`, e);
    }
  }

  entries = decrypted;
  chrome.action.setBadgeText({ text: String(entries.length) });
  chrome.action.setBadgeBackgroundColor({ color: '#00D4FF' });
}

// ─── Domain matching ───
function extractDomain(url: string): string {
  try {
    return new URL(url.startsWith('http') ? url : `https://${url}`).hostname.replace(/^www\./, '');
  } catch {
    return url.replace(/^www\./, '').split('/')[0];
  }
}

function matchesDomain(entryWebsite: string, pageDomain: string): boolean {
  if (!entryWebsite) return false;
  const entryDomain = extractDomain(entryWebsite);
  // Exact match or subdomain match
  return pageDomain === entryDomain ||
    pageDomain.endsWith('.' + entryDomain) ||
    entryDomain.endsWith('.' + pageDomain);
}

function getLoginsForDomain(domain: string): VaultEntry[] {
  return entries.filter(e =>
    e.category === 'login' && matchesDomain(e.website, domain)
  );
}

// ─── Check if user is Pro ───
async function checkIsPro(userId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('profiles')
      .select('is_pro')
      .eq('id', userId)
      .single();
    return data?.is_pro === true;
  } catch {
    return false;
  }
}

const FREE_LIMIT = 5;

// ─── Save new login ───
async function saveLogin(entry: VaultEntry): Promise<{ success: boolean; error?: string }> {
  if (!vek) return { success: false, error: 'Vault locked' };

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return { success: false, error: 'Not authenticated' };

  // Free users: block if already at 5+ entries
  const isPro = await checkIsPro(session.user.id);
  if (!isPro && entries.length >= FREE_LIMIT) {
    return { success: false, error: `Limite de ${FREE_LIMIT} identifiants atteinte. Passe a FyxxVault Pro pour un stockage illimite.` };
  }

  try {
    const blob = await encryptEntry(entry, vek);
    const { error } = await supabase.from('vault_items').insert({
      id: entry.id,
      user_id: session.user.id,
      encrypted_blob: encodeToSupabaseBytes(blob),
      updated_at: new Date().toISOString()
    });

    if (error) return { success: false, error: error.message };

    entries = [entry, ...entries];
    chrome.action.setBadgeText({ text: String(entries.length) });
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e.message };
  }
}

// ─── Unlock vault with master password ───
async function unlock(masterPassword: string): Promise<{ success: boolean; error?: string }> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return { success: false, error: 'Non authentifie. Connectez-vous sur FyxxVault.' };

  try {
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('wrapped_vek, vek_salt, vek_rounds')
      .eq('id', session.user.id)
      .single();

    if (profileError || !profile) {
      return { success: false, error: 'Profil introuvable.' };
    }

    const wrappedVek = decodeSupabaseBytes(profile.wrapped_vek);
    const salt = decodeSupabaseBytes(profile.vek_salt);
    const rounds = profile.vek_rounds || 210_000;

    const kek = await deriveKEK(masterPassword, salt, rounds);
    const unwrapped = await unwrapVEK(wrappedVek, kek);

    await persistVEK(unwrapped);
    await loadEntries();
    return { success: true };
  } catch (e: any) {
    if (e?.name === 'OperationError' || e?.message?.includes('decrypt')) {
      return { success: false, error: 'Mot de passe maitre incorrect.' };
    }
    return { success: false, error: e.message || 'Erreur inconnue.' };
  }
}

// ─── Message handler ───
chrome.runtime.onMessage.addListener((msg: ExtMessage, _sender, sendResponse) => {
  lastActivity = Date.now();

  const handle = async () => {
    switch (msg.type) {
      case 'LOGIN_AND_UNLOCK': {
        try {
          const { email, masterPassword } = msg as any;
          // Sign in with Supabase
          const { data, error: authError } = await supabase.auth.signInWithPassword({
            email,
            password: masterPassword
          });
          if (authError) return { success: false, error: authError.message };
          if (!data.session) return { success: false, error: 'Pas de session.' };

          // Now unlock the vault with the same master password
          return await unlock(masterPassword);
        } catch (e: any) {
          return { success: false, error: e.message || 'Erreur de connexion.' };
        }
      }

      case 'OPEN_CHROME_PASSWORDS': {
        chrome.tabs.create({ url: 'chrome://password-manager/settings' });
        return { success: true };
      }

      case 'GET_STATUS': {
        const hasSession = await ensureSession();
        // Restore VEK from session storage if SW restarted
        if (!vek) {
          const restored = await restoreVEK();
          if (restored && entries.length === 0) await loadEntries();
        }
        return {
          isAuthenticated: hasSession,
          isUnlocked: !!vek,
          entryCount: entries.length
        } satisfies ExtStatus;
      }

      case 'DISABLE_GOOGLE_PASSWORDS': {
        try {
          await new Promise<void>((resolve, reject) => {
            chrome.privacy.services.passwordSavingEnabled.set({ value: false }, () => {
              if (chrome.runtime.lastError) reject(chrome.runtime.lastError);
              else resolve();
            });
          });
          chrome.privacy.services.autofillAddressEnabled.set({ value: false });
          chrome.privacy.services.autofillCreditCardEnabled.set({ value: false });
          return { success: true };
        } catch (e: any) {
          return { success: false, error: e.message || 'Erreur' };
        }
      }

      case 'IMPORT_CSV_ENTRIES': {
        if (!vek) return { success: false, error: 'Coffre verrouille. Connecte-toi d\'abord sur FyxxVault.' };

        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return { success: false, error: 'Non authentifie. Connecte-toi sur FyxxVault.' };

        // Check free user limit before import
        const isPro = await checkIsPro(session.user.id);
        if (!isPro && entries.length >= FREE_LIMIT) {
          return { success: false, error: 'UPGRADE_PRO', needsPro: true };
        }

        try {
          let count = 0;
          for (const csvEntry of (msg as any).entries) {
            const entry: VaultEntry = {
              id: crypto.randomUUID(),
              title: csvEntry.name || extractDomain(csvEntry.url),
              username: csvEntry.username || '',
              password: csvEntry.password || '',
              website: csvEntry.url || '',
              notes: '',
              category: 'login',
              folder: '',
              tags: ['import-google'],
              isFavorite: false,
              mfaEnabled: false,
              mfaSecret: '',
              createdAt: new Date().toISOString(),
              lastModifiedAt: new Date().toISOString(),
              passwordHistory: []
            };

            const blob = await encryptEntry(entry, vek);
            const { error } = await supabase.from('vault_items').insert({
              id: entry.id,
              user_id: session.user.id,
              encrypted_blob: encodeToSupabaseBytes(blob),
              updated_at: new Date().toISOString()
            });

            if (!error) {
              entries.push(entry);
              count++;
            }
          }

          chrome.action.setBadgeText({ text: String(entries.length) });
          return { success: true, count };
        } catch (e: any) {
          return { success: false, error: e.message };
        }
      }

      case 'GET_LOGINS': {
        if (!vek) return { logins: [] };
        // Empty domain = return all entries (for popup list)
        if (!msg.domain) return { logins: entries };
        return { logins: getLoginsForDomain(msg.domain) };
      }

      case 'GET_TOTP': {
        if (!vek) return { code: null };
        const login = entries.find(e =>
          matchesDomain(e.website, msg.domain) && e.mfaEnabled && e.mfaSecret
        );
        if (!login?.mfaSecret) return { code: null };
        try {
          const code = await generateTOTP(login.mfaSecret);
          return { code };
        } catch {
          return { code: null };
        }
      }

      case 'SAVE_LOGIN': {
        return await saveLogin(msg.entry);
      }

      case 'UNLOCK': {
        return await unlock(msg.masterPassword);
      }

      case 'LOCK': {
        lock();
        return { success: true };
      }

      case 'BRIDGE_SESSION': {
        // Web app sends its Supabase session to the extension
        try {
          const { error } = await supabase.auth.setSession({
            access_token: msg.session.access_token,
            refresh_token: msg.session.refresh_token
          });
          if (error) return { success: false, error: error.message };
          return { success: true };
        } catch (e: any) {
          return { success: false, error: e.message };
        }
      }

      case 'BRIDGE_VEK': {
        try {
          await persistVEK(hexToBytes(msg.vekHex));
          await loadEntries();
          return { success: true };
        } catch (e: any) {
          return { success: false, error: e.message };
        }
      }

      default:
        return { error: 'Unknown message type' };
    }
  };

  handle().then(sendResponse);
  return true; // Keep message channel open for async response
});

// ─── External messages from web app (externally_connectable) ───
chrome.runtime.onMessageExternal.addListener((msg: ExtMessage, _sender, sendResponse) => {
  lastActivity = Date.now();

  const handle = async () => {
    if (msg.type === 'BRIDGE_SESSION') {
      try {
        const { error } = await supabase.auth.setSession({
          access_token: msg.session.access_token,
          refresh_token: msg.session.refresh_token
        });
        if (error) return { success: false, error: error.message };
        return { success: true };
      } catch (e: any) {
        return { success: false, error: e.message };
      }
    }

    if (msg.type === 'BRIDGE_VEK') {
      try {
        await persistVEK(hexToBytes(msg.vekHex));
        await loadEntries();
        return { success: true };
      } catch (e: any) {
        return { success: false, error: e.message };
      }
    }

    return { error: 'Unsupported external message' };
  };

  handle().then(sendResponse);
  return true;
});
