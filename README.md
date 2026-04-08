<p align="center">
  <img src="web/static/favicon.svg" width="90" height="90" alt="FyxxVault">
</p>

<h1 align="center">FyxxVault</h1>

<p align="center">
  <strong>Gestionnaire de mots de passe self-hosted. Zero-knowledge. 100% local.</strong><br>
  Tes donnees restent chez toi. Point.
</p>

<p align="center">
  <a href="#installation"><img src="https://img.shields.io/badge/Install-1_commande-00d4ff?style=for-the-badge" alt="Install"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL_3.0-8b5cf6?style=for-the-badge" alt="License"></a>
  <a href="#securite"><img src="https://img.shields.io/badge/Chiffrement-AES--256--GCM-00d4ff?style=for-the-badge" alt="Encryption"></a>
  <a href="https://github.com/Fyxx20/FyxxVault/stargazers"><img src="https://img.shields.io/github/stars/Fyxx20/FyxxVault?style=for-the-badge&color=8b5cf6" alt="Stars"></a>
</p>

<br>

<p align="center">
  <img src="FyxxVaultPromo.png" width="700" alt="FyxxVault Dashboard">
</p>

---

## Pourquoi FyxxVault ?

La plupart des gestionnaires stockent tes mots de passe sur leurs serveurs, facturent un abonnement, ou imposent un compte cloud. FyxxVault, c'est different :

- **100% local** — Tes donnees ne quittent jamais ta machine
- **Zero-knowledge** — Chiffrement AES-256-GCM cote client, le serveur ne voit que du bruit
- **Gratuit pour toujours** — Pas de premium, pas de limites, pas de piege
- **Open source** — Chaque ligne de code est auditable (GPL-3.0)
- **Zero dependance cloud** — Juste SQLite sur ta machine

---

## Installation

**Une seule commande :**

```bash
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
```

> **Windows :**
> ```powershell
> irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex
> ```

**Puis :**

```bash
fyxxvault start
```

Ouvre **http://localhost:3000** — c'est tout.

> **Pre-requis :** Node.js 18+ et git. C'est tout.

---

## Panel de controle

Un mini serveur separe sur le port **3001** qui te permet de demarrer/arreter le vault meme quand il est eteint.

```bash
fyxxvault-panel
```

Ouvre **http://localhost:3001** — tu vois le statut du serveur et tu peux l'allumer/eteindre en un clic.

---

## Commandes CLI

```bash
fyxxvault start        # Demarrer le serveur
fyxxvault stop         # Arreter le serveur
fyxxvault restart      # Redemarrer
fyxxvault status       # Voir si ca tourne + taille DB
fyxxvault backup       # Creer un backup de la DB
fyxxvault check        # Verification d'integrite SQLite
fyxxvault audit        # Audit des permissions fichiers
fyxxvault-panel        # Lancer le panel web (port 3001)
```

---

## Fonctionnalites

| Fonctionnalite | |
|---|---|
| Entrees illimitees | :white_check_mark: |
| Chiffrement AES-256-GCM | :white_check_mark: |
| PBKDF2-SHA256 (210K iterations) | :white_check_mark: |
| Generateur de mots de passe | :white_check_mark: |
| TOTP / 2FA | :white_check_mark: |
| Surveillance dark web (HIBP) | :white_check_mark: |
| Generateur d'identite | :white_check_mark: |
| Partage securise | :white_check_mark: |
| Import CSV (Chrome, 1Password, Bitwarden, Samsung Pass) | :white_check_mark: |
| Export CSV / JSON | :white_check_mark: |
| Kit d'urgence PDF | :white_check_mark: |
| Panel d'administration | :white_check_mark: |
| Verrouillage auto sur inactivite | :white_check_mark: |
| Pas de compte / pas d'email | :white_check_mark: |

---

## Architecture

```
                    Ta Machine
┌─────────────────────────────────────────────┐
│                                             │
│   Navigateur (localhost:3000)               │
│   ┌───────────────────────────────┐         │
│   │  Chiffrement AES-256-GCM     │         │
│   │  Derivation PBKDF2-SHA256    │         │
│   │  VEK en memoire uniquement   │         │
│   └──────────────┬────────────────┘         │
│                  │ blobs chiffres            │
│   ┌──────────────▼────────────────┐         │
│   │  SvelteKit + Node.js          │         │
│   │  API REST (localhost:3000)    │         │
│   └──────────────┬────────────────┘         │
│                  │                           │
│   ┌──────────────▼────────────────┐         │
│   │  SQLite (WAL mode)            │         │
│   │  ~/.fyxxvault/data/           │         │
│   │  Permissions: 0600            │         │
│   └───────────────────────────────┘         │
│                                             │
│   Panel de controle (localhost:3001)        │
│   ┌───────────────────────────────┐         │
│   │  Start / Stop du serveur      │         │
│   │  Stats, backup, export        │         │
│   └───────────────────────────────┘         │
│                                             │
└─────────────────────────────────────────────┘
          Rien ne sort de cette boite.
```

---

## Securite

FyxxVault utilise une architecture **zero-knowledge** :

1. Ton **mot de passe maitre** derive une cle (KEK) via PBKDF2-SHA256 avec **210 000 iterations**
2. Une **cle de chiffrement (VEK)** aleatoire est generee et protegee par la KEK en AES-256-GCM
3. Chaque entree du coffre est **individuellement chiffree** avec la VEK
4. Seuls des blobs chiffres sont stockes — le serveur **ne peut pas lire tes donnees**
5. La VEK est **en memoire uniquement** — jamais ecrite sur disque
6. Meme si quelqu'un accede au port 3000, il ne voit que du chiffre inexploitable

### Base de donnees

- SQLite en mode WAL (performance + crash safety)
- Permissions fichier `0600` (lecture/ecriture proprietaire uniquement)
- Foreign keys actives
- Aucune exposition reseau — localhost par defaut

> Trouve une faille ? Lis [SECURITY.md](SECURITY.md).

---

## Stack technique

| Composant | Technologie |
|---|---|
| Application web | SvelteKit 5, Svelte 5, Tailwind CSS 4, TypeScript |
| Serveur | SvelteKit + adapter-node |
| Base de donnees | SQLite via better-sqlite3 (WAL mode) |
| Chiffrement | Web Crypto API (AES-256-GCM, PBKDF2-SHA256) |
| Panel | Node.js HTTP natif (zero dependance) |

---

## Structure du projet

```
FyxxVault/
├── web/                        # Application SvelteKit
├── panel/                      # Panel de controle (port 3001)
│   └── server.js               # Serveur standalone
├── self-hosted/
│   ├── bin/fyxxvault.js        # CLI
│   └── scripts/
│       ├── install.sh          # Installateur
│       └── init-db.js          # Init base de donnees
├── macos/                      # Installateur macOS
├── linux/                      # Installateur Linux
├── windows/                    # Installateur Windows
└── SECURITY.md
```

---

## Comparaison

| | FyxxVault | 1Password | Bitwarden | LastPass |
|---|:-:|:-:|:-:|:-:|
| Prix | **Gratuit** | 2.99$/mois | 0-3$/mois | 3$/mois |
| Self-hosted | **Oui** | Non | Oui | Non |
| Open source | **Oui** | Non | Partiel | Non |
| Zero-knowledge | **Oui** | Oui | Oui | Non |
| Pas de cloud | **Oui** | Non | Non | Non |
| Entrees illimitees | **Oui** | Oui | Oui | Oui |
| TOTP / 2FA | **Oui** | Oui | Premium | Premium |
| Dark web monitoring | **Oui** | Premium | Premium | Premium |
| Pas de compte requis | **Oui** | Non | Non | Non |

---

## Configuration

Variables d'environnement (optionnelles) :

| Variable | Defaut | Description |
|---|---|---|
| `PORT` | `3000` | Port du serveur vault |
| `FYXXVAULT_DATA_DIR` | `~/.fyxxvault/data/` | Emplacement de la DB |

---

## Contribuer

1. Fork le repo
2. Cree une branche (`git checkout -b feature/ma-feature`)
3. Commit tes changements
4. Push et ouvre une Pull Request

---

## Licence

FyxxVault est sous licence [GNU General Public License v3.0](LICENSE).

Tu peux utiliser, modifier et distribuer FyxxVault librement — tout travail derive doit aussi etre open source sous la meme licence.

---

<p align="center">
  <br>
  <strong>Tes mots de passe. Ta machine. Tes regles.</strong>
  <br><br>
  Fait par <a href="https://github.com/Fyxx20">@Fyxx20</a><br>
  <sub>Parce que la securite devrait etre un droit, pas un abonnement.</sub>
</p>
