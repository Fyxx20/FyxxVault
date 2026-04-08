# FyxxVault — Linux

## Installation

1. Telecharger **[Install FyxxVault.sh](https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/linux/Install%20FyxxVault.sh)**
2. Clic droit > Proprietes > Permissions > Autoriser l'execution
3. Double-cliquer dessus

### Ou via Terminal

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/linux/install.sh | bash
```

---

## Prerequis

- **Node.js 18+** — [nodejs.org](https://nodejs.org)
- **git** + **build-essential**

```bash
# Ubuntu / Debian
sudo apt install -y nodejs npm git build-essential

# Fedora
sudo dnf install -y nodejs npm git gcc-c++ make

# Arch
sudo pacman -S nodejs npm git base-devel
```

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

## Lancer au demarrage (systemd)

```bash
sudo tee /etc/systemd/system/fyxxvault.service > /dev/null << EOF
[Unit]
Description=FyxxVault
After=network.target

[Service]
Type=simple
User=$USER
Environment=PORT=3000
Environment=FYXXVAULT_DATA_DIR=/home/$USER/.fyxxvault/data
ExecStart=/usr/bin/node /home/$USER/.fyxxvault/app/web/build/index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now fyxxvault
```

---

## Desinstaller

```bash
fyxxvault stop
rm -rf ~/.fyxxvault
```
