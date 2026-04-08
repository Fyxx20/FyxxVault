# FyxxVault — macOS

## Installation

1. Telecharger **[Install FyxxVault.command](https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/Install%20FyxxVault.command)**
2. Double-cliquer dessus
3. C'est tout

> Si macOS bloque le fichier : clic droit > Ouvrir > Ouvrir quand meme

### Ou via Terminal

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
```

---

## Prerequis

- **macOS 12+** (Monterey ou plus recent)
- **Node.js 18+** — [nodejs.org](https://nodejs.org)
- **git** — `xcode-select --install`

---

## Utilisation

```bash
fyxxvault start        # Demarrer → http://localhost:3000
fyxxvault stop         # Arreter
fyxxvault status       # Statut + infos
fyxxvault backup       # Sauvegarder la base
fyxxvault-panel        # Panel de gestion interactif
```

---

## Desinstaller

```bash
fyxxvault stop
rm -rf ~/.fyxxvault
```
