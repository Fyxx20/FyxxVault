import { writable } from 'svelte/store';

// Global unread inbox count for sidebar/nav badges.
export const inboxUnreadCount = writable(0);

