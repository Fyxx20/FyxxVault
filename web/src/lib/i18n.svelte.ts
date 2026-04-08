import { browser } from '$app/environment';
import fr from './translations/fr';
import en from './translations/en';

const translations: Record<string, Record<string, string>> = { fr, en };

let lang = $state<'fr' | 'en'>(
	browser ? ((localStorage.getItem('fv-lang') as 'fr' | 'en') || 'fr') : 'fr'
);

export function t(key: string): string {
	return translations[lang]?.[key] ?? translations['fr']?.[key] ?? key;
}

export function setLang(newLang: 'fr' | 'en') {
	lang = newLang;
	if (browser) localStorage.setItem('fv-lang', newLang);
}

export function getLang(): 'fr' | 'en' {
	return lang;
}
