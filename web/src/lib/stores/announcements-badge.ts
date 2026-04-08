import { writable, get } from 'svelte/store';

export const unreadAnnouncementsCount = writable(0);

const READ_KEY = 'fv_read_announcements';

export function checkUnreadAnnouncements(allIds: string[]) {
	try {
		const read = JSON.parse(localStorage.getItem(READ_KEY) || '[]') as string[];
		const unread = allIds.filter(id => !read.includes(id));
		unreadAnnouncementsCount.set(unread.length);
	} catch {
		unreadAnnouncementsCount.set(0);
	}
}

export function markAllAnnouncementsRead(allIds: string[]) {
	try {
		localStorage.setItem(READ_KEY, JSON.stringify(allIds));
		unreadAnnouncementsCount.set(0);
	} catch {
		// ignore
	}
}
