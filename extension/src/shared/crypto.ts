// Crypto utilities (adapted from web app's lib/crypto.ts)
// Uses Web Crypto API — works in extension service workers and content scripts

import type { VaultEntry } from './types';

const PBKDF2_ROUNDS_DEFAULT = 210_000;
const AES_KEY_BITS = 256;
const IV_LENGTH = 12;

function getSubtle(): SubtleCrypto {
  if (typeof globalThis.crypto?.subtle === 'undefined') {
    throw new Error('Web Crypto API non disponible.');
  }
  return globalThis.crypto.subtle;
}

export async function deriveKEK(
  masterPassword: string,
  salt: Uint8Array,
  rounds: number = PBKDF2_ROUNDS_DEFAULT
): Promise<CryptoKey> {
  const enc = new TextEncoder();
  const keyMaterial = await getSubtle().importKey(
    'raw',
    enc.encode(masterPassword),
    'PBKDF2',
    false,
    ['deriveKey']
  );
  return getSubtle().deriveKey(
    { name: 'PBKDF2', salt, iterations: rounds, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: AES_KEY_BITS },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function unwrapVEK(wrapped: Uint8Array, kek: CryptoKey): Promise<Uint8Array> {
  const iv = wrapped.slice(0, IV_LENGTH);
  const ciphertext = wrapped.slice(IV_LENGTH);
  const plaintext = await getSubtle().decrypt({ name: 'AES-GCM', iv }, kek, ciphertext);
  return new Uint8Array(plaintext);
}

async function importVEKKey(vek: Uint8Array): Promise<CryptoKey> {
  return getSubtle().importKey('raw', vek, { name: 'AES-GCM', length: AES_KEY_BITS }, false, ['encrypt', 'decrypt']);
}

export async function encryptEntry(entry: VaultEntry, vek: Uint8Array): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const plaintext = enc.encode(JSON.stringify(entry));
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const key = await importVEKKey(vek);
  const ciphertext = await getSubtle().encrypt({ name: 'AES-GCM', iv }, key, plaintext);
  const result = new Uint8Array(IV_LENGTH + ciphertext.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(ciphertext), IV_LENGTH);
  return result;
}

export async function decryptEntry(blob: Uint8Array, vek: Uint8Array): Promise<VaultEntry> {
  const iv = blob.slice(0, IV_LENGTH);
  const ciphertext = blob.slice(IV_LENGTH);
  const key = await importVEKKey(vek);
  const plaintext = await getSubtle().decrypt({ name: 'AES-GCM', iv }, key, ciphertext);
  const dec = new TextDecoder();
  return JSON.parse(dec.decode(plaintext)) as VaultEntry;
}

// ─── Hex helpers ───
export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

export function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

// ─── Supabase BYTEA helpers ───
export function decodeSupabaseBytes(value: any): Uint8Array {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (typeof value === 'string') {
    let hex = value;
    if (hex.startsWith('\\x')) hex = hex.slice(2);
    if (hex.startsWith('0x')) hex = hex.slice(2);
    return hexToBytes(hex);
  }
  throw new Error('Unexpected BYTEA format');
}

export function encodeToSupabaseBytes(bytes: Uint8Array): string {
  return '\\x' + bytesToHex(bytes);
}
