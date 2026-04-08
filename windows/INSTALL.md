# FyxxVault — Installation Windows

## Prerequis

- **Windows 10** (version 1903+) ou **Windows 11**
- **Node.js 18+** — [Telecharger](https://nodejs.org) (choisir LTS)
- **git** — [Telecharger](https://git-scm.com/download/win)

### Installer les prerequis

1. Telecharger et installer **Node.js LTS** depuis [nodejs.org](https://nodejs.org)
   - Cocher "Automatically install necessary tools" pendant l'installation
2. Telecharger et installer **Git** depuis [git-scm.com](https://git-scm.com/download/win)
   - Garder les options par defaut

Verifier dans PowerShell :
```powershell
node -v    # doit afficher v18+ ou v20+
git --version
```

---

## Installation rapide

Ouvrez **PowerShell** (clic droit sur le menu Demarrer > Terminal) et collez :

```powershell
irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex
```

> **Note :** Si vous avez une erreur de politique d'execution, lancez d'abord :
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

L'installateur va :
1. Verifier Node.js, npm, git
2. Telecharger FyxxVault dans `C:\Users\VOTRENOM\.fyxxvault\`
3. Installer les dependances
4. Compiler l'application
5. Initialiser la base SQLite
6. Ajouter `fyxxvault` au PATH Windows

---

## Demarrer le serveur

```powershell
fyxxvault start
```

Puis ouvrez **http://localhost:3000** dans Chrome, Edge ou Firefox.

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

---

## Fichiers installes

```
C:\Users\VOTRENOM\.fyxxvault\
├── app\        Application FyxxVault
├── data\       Base de donnees SQLite (fyxxvault.db)
├── logs\       Logs du serveur
└── bin\        Commande CLI (fyxxvault.cmd)
```

---

## Faire tourner au demarrage (optionnel)

Creer un raccourci dans le dossier Demarrage :

1. Appuyez sur `Win + R`, tapez `shell:startup`, Entree
2. Creer un raccourci avec la cible :
   ```
   node C:\Users\VOTRENOM\.fyxxvault\app\web\build\index.js
   ```
3. Clic droit > Proprietes > Ajouter les variables d'environnement :
   - `PORT=3000`
   - `FYXXVAULT_DATA_DIR=C:\Users\VOTRENOM\.fyxxvault\data`

---

## Desinstaller

1. Arreter le serveur : `fyxxvault stop`
2. Supprimer le dossier : `Remove-Item -Recurse -Force "$env:USERPROFILE\.fyxxvault"`
3. Nettoyer le PATH :
   - Parametres > Systeme > Variables d'environnement
   - Retirer `%USERPROFILE%\.fyxxvault\bin` du Path utilisateur
