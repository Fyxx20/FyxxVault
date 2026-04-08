# FyxxVault — Linux

## 1. Installer

Ouvrez un terminal et collez cette ligne :

```
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/linux/install.sh | bash
```

L'installation est 100% automatique (environ 2 minutes).

## 2. Lancer

A la fin de l'installation, copiez la commande affichee :

```
~/.fyxxvault/bin/fyxxvault start
```

## 3. Ouvrir

Allez sur **http://localhost:3000** dans votre navigateur et creez votre mot de passe maitre.

---

## Prerequis

- **Node.js 18+** → [Telecharger ici](https://nodejs.org)
- **git** → `sudo apt install git`
- **build-essential** → `sudo apt install build-essential`

## Desinstaller

```
~/.fyxxvault/bin/fyxxvault stop
rm -rf ~/.fyxxvault
```
