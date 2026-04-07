// FyxxVault Extension — Service Worker (Manifest V3)
// Manages: Supabase session, VEK in memory, vault entries cache, messaging

import { supabase } from '../shared/supabase';
import { decryptEntry, encryptEntry, decodeSupabaseBytes, encodeToSupabaseBytes, deriveKEK, unwrapVEK, hexToBytes, bytesToHex } from '../shared/crypto';
import { newVaultEntry, DEFAULT_SETTINGS } from '../shared/types';
import { generateTOTP } from '../shared/totp';
import type { VaultEntry, ExtMessage, ExtStatus, ExtSettings } from '../shared/types';

// ─── Disable Chrome's built-in password manager ───
function disableChromePasswordManager() {
  chrome.privacy.services.passwordSavingEnabled.set({ value: false }, () => {
    if (chrome.runtime.lastError) {
      console.error('Failed to disable passwordSaving:', chrome.runtime.lastError);
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

// ─── Auto-lock alarm ───
async function setupAutoLock() {
  const settings = await getSettings();
  await chrome.alarms.clear('fyxx-autolock');
  if (settings.autoLockMinutes > 0) {
    chrome.alarms.create('fyxx-autolock', { periodInMinutes: 1 });
  }
}

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'fyxx-autolock' && vek) {
    const settings = await getSettings();
    if (settings.autoLockMinutes > 0) {
      const elapsed = (Date.now() - lastActivity) / 60000;
      if (elapsed >= settings.autoLockMinutes) {
        lock();
      }
    }
  }
});

// ─── Settings ───
async function getSettings(): Promise<ExtSettings> {
  const { fyxxSettings } = await chrome.storage.local.get('fyxxSettings');
  return { ...DEFAULT_SETTINGS, ...(fyxxSettings || {}) };
}

async function updateSettings(partial: Partial<ExtSettings>): Promise<ExtSettings> {
  const current = await getSettings();
  const updated = { ...current, ...partial };
  await chrome.storage.local.set({ fyxxSettings: updated });
  if ('autoLockMinutes' in partial) await setupAutoLock();
  if ('disableChromePasswords' in partial && partial.disableChromePasswords) {
    disableChromePasswordManager();
  }
  return updated;
}

// ─── Restore VEK on service worker wake ───
restoreVEK().then(async (restored) => {
  if (restored) {
    await loadEntries();
  }
  await setupAutoLock();
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
  return pageDomain === entryDomain ||
    pageDomain.endsWith('.' + entryDomain) ||
    entryDomain.endsWith('.' + pageDomain);
}

function getLoginsForDomain(domain: string): VaultEntry[] {
  return entries.filter(e =>
    e.category === 'login' && matchesDomain(e.website, domain)
  );
}

// ─── Save new login ───
async function saveLogin(entry: VaultEntry): Promise<{ success: boolean; error?: string }> {
  if (!vek) return { success: false, error: 'Vault locked' };

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return { success: false, error: 'Not authenticated' };

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

// ─── Delete entry (soft delete) ───
async function deleteEntry(entryId: string): Promise<{ success: boolean; error?: string }> {
  if (!vek) return { success: false, error: 'Vault locked' };

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return { success: false, error: 'Not authenticated' };

  try {
    const { error } = await supabase
      .from('vault_items')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', entryId)
      .eq('user_id', session.user.id);

    if (error) return { success: false, error: error.message };

    entries = entries.filter(e => e.id !== entryId);
    chrome.action.setBadgeText({ text: String(entries.length) });
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e.message };
  }
}

// ─── Password generator ───
function generatePassword(length: number, opts: { uppercase: boolean; lowercase: boolean; digits: boolean; symbols: boolean }): string {
  let charset = '';
  if (opts.lowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
  if (opts.uppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (opts.digits) charset += '0123456789';
  if (opts.symbols) charset += '!@#$%^&*()-_=+[]{}|;:,.<>?';
  if (!charset) charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  const maxValid = 256 - (256 % charset.length);
  const result: string[] = [];
  while (result.length < length) {
    const array = crypto.getRandomValues(new Uint8Array(length - result.length + 16));
    for (const byte of array) {
      if (byte < maxValid && result.length < length) {
        result.push(charset[byte % charset.length]);
      }
    }
  }
  return result.join('');
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
          const { data, error: authError } = await supabase.auth.signInWithPassword({
            email,
            password: masterPassword
          });
          if (authError) return { success: false, error: authError.message };
          if (!data.session) return { success: false, error: 'Pas de session.' };
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
        if (!vek) {
          const restored = await restoreVEK();
          if (restored && entries.length === 0) await loadEntries();
        }
        // Get user email for settings display
        let userEmail: string | undefined;
        if (hasSession) {
          const { data: { session } } = await supabase.auth.getSession();
          userEmail = session?.user?.email;
        }
        return {
          isAuthenticated: hasSession,
          isUnlocked: !!vek,
          entryCount: entries.length,
          userEmail
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
        if (!vek) return { success: false, error: 'Coffre verrouille.' };

        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return { success: false, error: 'Non authentifie.' };

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

      case 'DELETE_ENTRY': {
        return await deleteEntry(msg.entryId);
      }

      case 'UNLOCK': {
        return await unlock(msg.masterPassword);
      }

      case 'LOCK': {
        lock();
        return { success: true };
      }

      case 'LOGOUT': {
        lock();
        await supabase.auth.signOut();
        return { success: true };
      }

      case 'GET_ALIASES': {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return { aliases: [] };
        const { data, error } = await supabase
          .from('email_aliases')
          .select('id, address, label, is_active, emails_received, created_at')
          .eq('user_id', session.user.id)
          .order('created_at', { ascending: false });
        return { aliases: error ? [] : (data || []) };
      }

      case 'GET_EMAILS': {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return { emails: [] };
        const { data, error } = await supabase
          .from('emails')
          .select('id, alias_id, from_address, from_name, to_address, subject, body_text, is_read, is_starred, received_at')
          .eq('user_id', session.user.id)
          .eq('alias_id', msg.aliasId)
          .order('received_at', { ascending: false })
          .limit(50);
        return { emails: error ? [] : (data || []) };
      }

      case 'TOGGLE_ALIAS': {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return { success: false };
        const { error } = await supabase
          .from('email_aliases')
          .update({ is_active: msg.active })
          .eq('id', msg.aliasId)
          .eq('user_id', session.user.id);
        return { success: !error };
      }

      case 'GET_SETTINGS': {
        return await getSettings();
      }

      case 'UPDATE_SETTINGS': {
        const updated = await updateSettings(msg.settings);
        return { success: true, settings: updated };
      }

      case 'GENERATE_PASSWORD': {
        const password = generatePassword(msg.length, {
          uppercase: msg.uppercase,
          lowercase: msg.lowercase,
          digits: msg.digits,
          symbols: msg.symbols
        });
        return { password };
      }

      case 'BRIDGE_SESSION': {
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
