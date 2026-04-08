# FyxxVault — Installation macOS

## Prerequis

- **macOS** 12 (Monterey) ou plus recent
- **Node.js 18+** — [Telecharger](https://nodejs.org)
- **git** — Inclus avec Xcode Command Line Tools

### Installer les prerequis (si besoin)

```bash
# Installer Xcode Command Line Tools (inclut git)
xcode-select --install

# Installer Node.js via Homebrew
brew install node
```

---

## Installation rapide

Ouvrez **Terminal** et collez cette commande :

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
```

C'est tout. L'installateur va :
1. Verifier Node.js, npm, git
2. Telecharger FyxxVault dans `~/.fyxxvault/`
3. Installer les dependances
4. Compiler l'application
5. Initialiser la base SQLite
6. Ajouter la commande `fyxxvault` au PATH

---

## Demarrer le serveur

```bash
fyxxvault start
```

Puis ouvrez **http://localhost:3000** dans Safari ou Chrome.

---

## Commandes utiles

| Commande | Description |
|----------|-------------|
| `fyxxvault start` | Demarrer le serveur |
| `fyxxvault stop` | Arreter le serveur |
| `fyxxvault status` | Voir le statut |
| `fyxxvault backup` | Sauvegarder la base |
| `fyxxvault check` | Verification d'integrite |
| `fyxxvault-panel` | Ouvrir le panel de gestion |

---

## Fichiers installes

```
~/.fyxxvault/
├── app/        Application FyxxVault
├── data/       Base de donnees SQLite (fyxxvault.db)
├── logs/       Logs du serveur
└── bin/        Commande CLI (fyxxvault)
```

---

## Desinstaller

```bash
fyxxvault stop
rm -rf ~/.fyxxvault
```

Puis retirez la ligne `export PATH="$HOME/.fyxxvault/bin:$PATH"` de votre `~/.zshrc`.
