# FyxxVault — Windows

## Installation

**Methode 1 — Double-clic :**

1. Telecharger [Install FyxxVault.bat](https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/Install%20FyxxVault.bat)
2. Double-cliquer dessus
3. Si SmartScreen bloque : "Informations complementaires" > "Executer quand meme"

**Methode 2 — PowerShell :**

```powershell
irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex
```

Puis lancez :

```powershell
fyxxvault start
```

Ouvrez **http://localhost:3000** — c'est pret.

---

## Prerequis

| | |
|---|---|
| **Windows** | 10 ou 11 |
| **Node.js** | 18+ — [nodejs.org](https://nodejs.org) |
| **git** | [git-scm.com](https://git-scm.com/download/win) |

---

## Commandes

```powershell
fyxxvault start        # Demarrer le serveur
fyxxvault stop         # Arreter
fyxxvault status       # Statut + infos DB
fyxxvault backup       # Sauvegarder la base
fyxxvault check        # Verification d'integrite
```

---

## Desinstaller

```powershell
fyxxvault stop
Remove-Item -Recurse -Force "$env:USERPROFILE\.fyxxvault"
```
