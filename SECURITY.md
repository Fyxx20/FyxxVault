# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in FyxxVault, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email us at: **security@fyxxvault.com**

We will acknowledge your report within 48 hours and provide a timeline for a fix.

## Scope

The following are in scope for security reports:

- FyxxVault web application (fyxxvault.com)
- FyxxVault browser extension
- FyxxVault iOS application
- Encryption implementation (AES-256-GCM, PBKDF2)
- Authentication and session management
- API endpoints
- Data storage and transmission

## Out of Scope

- Social engineering attacks
- Denial of service attacks
- Issues in third-party dependencies (report to the upstream project)

## Security Architecture

FyxxVault uses a **zero-knowledge architecture**:

- All vault data is encrypted client-side with **AES-256-GCM** before leaving your device
- Your master password is never transmitted or stored — only a derived key (PBKDF2-SHA256, 210,000 iterations) is used
- The server only sees encrypted blobs — we cannot read your data
- The Vault Encryption Key (VEK) is wrapped with a Key Encryption Key (KEK) derived from your master password

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest  | Yes       |

## Acknowledgements

We appreciate security researchers who help keep FyxxVault safe. Responsible reporters will be credited in this file (with permission).
