# FyxxVault — macOS

## Installation

1. Telecharger **[Install FyxxVault.command](https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/Install%20FyxxVault.command)**
2. **Clic droit** sur le fichier > **Ouvrir** (important : ne pas double-cliquer)
3. Cliquer **Ouvrir** dans la popup de confirmation
4. L'installation se lance automatiquement

> **Pourquoi clic droit ?** macOS bloque par defaut les fichiers telecharges d'internet. Le clic droit > Ouvrir permet de contourner cette protection une seule fois.

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
