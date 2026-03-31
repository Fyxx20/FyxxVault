// Post-build: copy static files (manifest, icons, popup.html, CSS) to dist/
import { cpSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');
const dist = resolve(root, 'dist');

// Ensure dist exists
mkdirSync(dist, { recursive: true });

// Copy manifest.json
cpSync(resolve(root, 'manifest.json'), resolve(dist, 'manifest.json'));

// Copy source icons (SVG source for generate-icons.js)
const iconsDir = resolve(root, 'src/icons');
mkdirSync(resolve(dist, 'icons'), { recursive: true });
if (existsSync(iconsDir)) {
  cpSync(iconsDir, resolve(dist, 'icons'), { recursive: true });
}

// Copy popup.html and popup.css
cpSync(resolve(root, 'src/popup/popup.html'), resolve(dist, 'popup/popup.html'));
cpSync(resolve(root, 'src/popup/popup.css'), resolve(dist, 'popup/popup.css'));

// Copy content script CSS
cpSync(resolve(root, 'src/content/autofill.css'), resolve(dist, 'content/autofill.css'));

console.log('Static files copied to dist/');
