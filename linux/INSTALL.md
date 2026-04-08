# FyxxVault — Installation Linux

## Prerequis

- **Linux** Ubuntu 20.04+, Debian 11+, Fedora 36+, Arch, ou toute distribution recente
- **Node.js 18+** — [Telecharger](https://nodejs.org)
- **git**
- **build-essential** (pour compiler better-sqlite3)

### Installer les prerequis

**Ubuntu / Debian :**
```bash
sudo apt update
sudo apt install -y nodejs npm git build-essential
```

**Fedora :**
```bash
sudo dnf install -y nodejs npm git gcc-c++ make
```

**Arch :**
```bash
sudo pacman -S nodejs npm git base-devel
```

**Via NodeSource (recommande pour Node.js 20+) :**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git build-essential
```

---

## Installation rapide

Ouvrez un terminal et collez cette commande :

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/linux/install.sh | bash
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

Puis ouvrez **http://localhost:3000** dans votre navigateur.

---

## Faire tourner en service (systemd)

Pour que FyxxVault demarre automatiquement :

```bash
sudo tee /etc/systemd/system/fyxxvault.service > /dev/null << EOF
[Unit]
Description=FyxxVault Password Manager
After=network.target

[Service]
Type=simple
User=$USER
Environment=PORT=3000
Environment=FYXXVAULT_DATA_DIR=/home/$USER/.fyxxvault/data
WorkingDirectory=/home/$USER/.fyxxvault/app/web
ExecStart=/usr/bin/node /home/$USER/.fyxxvault/app/web/build/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fyxxvault
sudo systemctl start fyxxvault
```

Verifier le statut :
```bash
sudo systemctl status fyxxvault
```

---

## Commandes utiles

| Commande | Description |
|----------|-------------|
| `fyxxvault start` | Demarrer le serveur |
| `fyxxvault stop` | Arreter le serveur |
| `fyxxvault status` | Voir le statut |
| `fyxxvault backup` | Sauvegarder la base |
| `fyxxvault check` | Verification d'integrite |
| `fyxxvault audit` | Audit de securite |
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

Puis retirez la ligne `export PATH="$HOME/.fyxxvault/bin:$PATH"` de votre `~/.bashrc` ou `~/.zshrc`.

Si vous aviez un service systemd :
```bash
sudo systemctl stop fyxxvault
sudo systemctl disable fyxxvault
sudo rm /etc/systemd/system/fyxxvault.service
sudo systemctl daemon-reload
```
