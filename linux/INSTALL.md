# FyxxVault — Linux

## Installation

Ouvrez un terminal et collez :

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/linux/install.sh | bash
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
| **Node.js** | 18+ — [nodejs.org](https://nodejs.org) |
| **git** | `sudo apt install git` |
| **build-essential** | `sudo apt install build-essential` |

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
