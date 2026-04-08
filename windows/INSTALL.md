# FyxxVault — Windows

## 1. Installer

Ouvrez **PowerShell** (clic droit menu Demarrer → Terminal) et collez :

```
irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex
```

L'installation est 100% automatique (environ 2 minutes).

## 2. Lancer

Fermez et rouvrez PowerShell, puis tapez :

```
fyxxvault start
```

## 3. Ouvrir

Allez sur **http://localhost:3000** dans votre navigateur et creez votre mot de passe maitre.

---

## Prerequis

- **Windows 10 ou 11**
- **Node.js 18+** → [Telecharger ici](https://nodejs.org)
- **git** → [Telecharger ici](https://git-scm.com/download/win)

## Desinstaller

```
fyxxvault stop
Remove-Item -Recurse -Force "$env:USERPROFILE\.fyxxvault"
```
