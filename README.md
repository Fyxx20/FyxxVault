<p align="center">
  <img src="web/static/favicon.svg" width="80" height="80" alt="FyxxVault">
</p>

<h1 align="center">FyxxVault</h1>

<p align="center">
  <strong>The free, open-source password manager that respects your privacy.</strong><br>
  No investors. No limits. No compromise.
</p>

<p align="center">
  <a href="https://fyxxvault.com">Website</a> &bull;
  <a href="https://chrome.google.com/webstore/detail/fyxxvault">Chrome Extension</a> &bull;
  <a href="#security">Security</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

## Why FyxxVault?

Most password managers either charge for basic features or harvest your data. FyxxVault is different:

- **100% free** — No premium plan, no feature gates, no trial periods
- **Zero-knowledge** — Your data is encrypted on your device before it ever reaches our servers
- **Open source** — Every line of code is auditable
- **No investors** — Built by one developer who believes security should be accessible to everyone

## Features

- **Unlimited vault entries** — Passwords, credit cards, identities, secure notes, bank accounts, Wi-Fi, licenses
- **AES-256-GCM encryption** — Military-grade client-side encryption
- **PBKDF2-SHA256** — 210,000 iterations for key derivation
- **Browser autofill** — Smart detection and filling across all websites
- **TOTP/2FA codes** — Built-in authenticator, no separate app needed
- **Dark web monitoring** — Check if your credentials have been leaked (via Have I Been Pwned)
- **Disposable email aliases** — Generate unlimited @fyxxmail.com addresses with custom names
- **Identity generator** — Create fictional identities for signups
- **Secure sharing** — Share credentials with end-to-end encryption
- **Cross-platform sync** — Web, Chrome extension, iOS app
- **Password generator** — Cryptographically secure with rejection sampling
- **CSV import/export** — Migrate from Chrome, 1Password, Bitwarden, LastPass

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Web App     │     │  Extension   │     │  iOS App     │
│  (SvelteKit) │     │  (Chrome MV3)│     │  (SwiftUI)   │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       │    Client-side AES-256-GCM encryption   │
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                   ┌────────▼────────┐
                   │   Supabase      │
                   │   (PostgreSQL)  │
                   │   Only stores   │
                   │  encrypted blobs│
                   └─────────────────┘
```

**Your master password never leaves your device.** The server only stores encrypted data that we cannot decrypt.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Web frontend | SvelteKit 5, Tailwind CSS, TypeScript |
| Browser extension | Chrome MV3, TypeScript, Vite |
| iOS app | SwiftUI, native iOS |
| Backend | SvelteKit server routes, Netlify Functions |
| Database | PostgreSQL via Supabase (with Row-Level Security) |
| Email forwarding | Cloudflare Workers |
| Encryption | Web Crypto API (AES-256-GCM, PBKDF2-SHA256) |

## Security

FyxxVault uses a **zero-knowledge architecture**:

1. Your **master password** derives a Key Encryption Key (KEK) using PBKDF2-SHA256 with 210,000 iterations
2. A random **Vault Encryption Key (VEK)** is generated and wrapped (encrypted) with the KEK
3. Each vault entry is individually encrypted with AES-256-GCM using the VEK
4. Only encrypted blobs are sent to the server — **we cannot read your data**
5. The VEK is held in memory only while your vault is unlocked — never persisted to disk

Found a vulnerability? Please read [SECURITY.md](SECURITY.md) for responsible disclosure.

## Self-Hosting

FyxxVault can be self-hosted. You'll need:

1. A [Supabase](https://supabase.com) project (free tier works)
2. A [Netlify](https://netlify.com) account (free tier works)

```bash
# Clone the repo
git clone https://github.com/Fyxx20/FyxxVault.git
cd FyxxVault

# Setup the web app
cd web
cp .env.example .env
# Edit .env with your Supabase credentials
npm install
npm run dev

# Setup the extension
cd ../extension
npm install
npm run build
# Load extension/dist as unpacked extension in Chrome
```

## Project Structure

```
FyxxVault/
├── web/                    # SvelteKit web application
│   ├── src/
│   │   ├── lib/            # Shared utilities, crypto, stores
│   │   └── routes/         # Pages and API endpoints
│   └── static/             # Static assets
├── extension/              # Chrome browser extension
│   └── src/
│       ├── popup/          # Extension popup UI
│       ├── background/     # Service worker
│       ├── content/        # Content scripts (autofill, bridge)
│       └── shared/         # Shared types and crypto
├── ios/                    # Native iOS app (SwiftUI)
├── cloudflare-worker/      # Email forwarding worker
└── supabase/               # Database migrations
```

## Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please make sure your code follows the existing patterns and doesn't introduce security vulnerabilities.

## Comparison

| Feature | FyxxVault | 1Password | Bitwarden | LastPass |
|---------|-----------|-----------|-----------|----------|
| Price | **Free** | $2.99/mo | $0-3/mo | $3/mo |
| Open Source | **Yes** | No | Yes | No |
| Zero-knowledge | **Yes** | Yes | Yes | No |
| Unlimited entries | **Yes** | Yes | Yes | Yes |
| Dark web monitoring | **Yes** | Yes | No | Yes |
| Email aliases | **Yes** | Yes | No | No |
| Identity generator | **Yes** | No | No | No |
| Self-hostable | **Yes** | No | Yes | No |

## License

FyxxVault is licensed under the [GNU General Public License v3.0](LICENSE).

This means you can use, modify, and distribute FyxxVault freely — but any derivative work must also be open source under the same license.

---

<p align="center">
  Built with conviction by <a href="https://github.com/Fyxx20">@Fyxx20</a><br>
  <em>Because security should be a right, not a subscription.</em>
</p>
