# FyxxVault — macOS

## Installation

Ouvrez **Terminal** et collez :

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
```

Puis lancez :

```bash
fyxxvault start
```

Ouvrez **http://localhost:3000** — c'est pret.

---

## Prerequis

| | |
|---|---|
| **macOS** | 12+ (Monterey ou plus recent) |
| **Node.js** | 18+ — [nodejs.org](https://nodejs.org) |
| **git** | `xcode-select --install` |

---

## Commandes

```bash
fyxxvault start        # Demarrer le serveur
fyxxvault stop         # Arreter
fyxxvault status       # Statut + infos DB
fyxxvault backup       # Sauvegarder la base
fyxxvault check        # Verification d'integrite
fyxxvault-panel        # Panel de gestion
```

---

## Desinstaller

```bash
fyxxvault stop
rm -rf ~/.fyxxvault
```
