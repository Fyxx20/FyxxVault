// Generate PNG icons from SVG for the Chrome extension
// Uses sharp if available, otherwise copies SVG as fallback
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');
const srcIcons = resolve(root, 'src', 'icons');
const distIcons = resolve(root, 'dist', 'icons');

mkdirSync(distIcons, { recursive: true });

const svgPath = resolve(srcIcons, 'icon.svg');
const svgContent = readFileSync(svgPath, 'utf-8');

const sizes = [16, 48, 128];

async function generateWithSharp() {
  const sharp = (await import('sharp')).default;
  for (const size of sizes) {
    await sharp(Buffer.from(svgContent))
      .resize(size, size)
      .png()
      .toFile(resolve(distIcons, `icon-${size}.png`));
    console.log(`Generated icon-${size}.png`);
  }
}

function generateSVGFallback() {
  // Chrome actually accepts SVG as icon in some contexts
  // For each size, create a sized SVG
  for (const size of sizes) {
    const sizedSvg = svgContent.replace(/viewBox="0 0 512 512"/, `viewBox="0 0 512 512" width="${size}" height="${size}"`);
    writeFileSync(resolve(distIcons, `icon-${size}.svg`), sizedSvg);
    console.log(`Generated icon-${size}.svg (SVG fallback)`);
  }
}

try {
  await generateWithSharp();
} catch {
  console.log('sharp not found, using SVG fallback. Install sharp for PNG icons: npm i -D sharp');
  generateSVGFallback();
}
