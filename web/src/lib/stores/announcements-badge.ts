import { writable } from 'svelte/store';
import { browser } from '$app/environment';

const STORAGE_KEY = 'fv-seen-announcements';

function getSeenIds(): Set<string> {
	if (!browser) return new Set();
	try {
		const raw = localStorage.getItem(STORAGE_KEY);
		return raw ? new Set(JSON.parse(raw)) : new Set();
	} catch {
		return new Set();
	}
}

function saveSeenIds(ids: Set<string>) {
	if (!browser) return;
	localStorage.setItem(STORAGE_KEY, JSON.stringify([...ids]));
}

export const unreadAnnouncementsCount = writable(0);

export function checkUnreadAnnouncements(announcementIds: string[]) {
	const seen = getSeenIds();
	const unread = announcementIds.filter(id => !seen.has(id)).length;
	unreadAnnouncementsCount.set(unread);
}

export function markAllAnnouncementsRead(announcementIds: string[]) {
	const seen = getSeenIds();
	for (const id of announcementIds) seen.add(id);
	saveSeenIds(seen);
	unreadAnnouncementsCount.set(0);
}
