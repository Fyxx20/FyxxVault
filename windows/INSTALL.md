# FyxxVault — Windows

## Installation

1. Telecharger **[Install FyxxVault.bat](https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/Install%20FyxxVault.bat)**
2. Double-cliquer dessus
3. C'est tout

> Si Windows SmartScreen bloque : "Informations complementaires" > "Executer quand meme"

### Ou via PowerShell

```powershell
irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex
```

---

## Prerequis

- **Windows 10/11**
- **Node.js 18+** — [nodejs.org](https://nodejs.org) (cocher "install necessary tools")
- **git** — [git-scm.com](https://git-scm.com/download/win)

---

## Utilisation

```powershell
fyxxvault start        # Demarrer → http://localhost:3000
fyxxvault stop         # Arreter
fyxxvault status       # Statut + infos
fyxxvault backup       # Sauvegarder la base
```

---

## Desinstaller

```powershell
fyxxvault stop
Remove-Item -Recurse -Force "$env:USERPROFILE\.fyxxvault"
```

Puis retirer `%USERPROFILE%\.fyxxvault\bin` du PATH dans Parametres > Variables d'environnement.
