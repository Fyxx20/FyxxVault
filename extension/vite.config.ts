import { defineConfig } from 'vite';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

export default defineConfig({
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        'background/service-worker': resolve(__dirname, 'src/background/service-worker.ts'),
        'content/autofill': resolve(__dirname, 'src/content/autofill.ts'),
        'content/bridge': resolve(__dirname, 'src/content/bridge.ts'),
        'content/bridge-main': resolve(__dirname, 'src/content/bridge-main.ts'),
        'popup/popup': resolve(__dirname, 'src/popup/popup.ts'),
      },
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: 'shared/[name]-[hash].js',
        assetFileNames: '[name].[ext]',
        // Inline everything — content scripts can't load ES module chunks
        inlineDynamicImports: false,
      },
    },
    target: 'esnext',
    minify: false,
    sourcemap: process.env.NODE_ENV !== 'production' ? 'inline' : false,
  },
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production'),
  },
  resolve: {
    alias: {
      '@shared': resolve(__dirname, 'src/shared'),
    },
  },
});
