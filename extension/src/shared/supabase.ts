// Supabase client for browser extension
// Session is stored in chrome.storage.local instead of localStorage

import { createClient } from '@supabase/supabase-js';
import type { SupabaseClient } from '@supabase/supabase-js';

// Public keys (safe to embed — these are the same as the web app)
const SUPABASE_URL = 'https://oqcmbgtpqjzfscymnije.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xY21iZ3RwcWp6ZnNjeW1uaWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzYwMzgsImV4cCI6MjA5MDA1MjAzOH0.7DUCw6ZloZ1DASnxWjeQivk8Jij5NYORtZR-sdigZ94';

// Custom storage adapter using chrome.storage.local
const chromeStorageAdapter = {
  async getItem(key: string): Promise<string | null> {
    const result = await chrome.storage.local.get(key);
    return result[key] ?? null;
  },
  async setItem(key: string, value: string): Promise<void> {
    await chrome.storage.local.set({ [key]: value });
  },
  async removeItem(key: string): Promise<void> {
    await chrome.storage.local.remove(key);
  }
};

export const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: chromeStorageAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false
  }
});
