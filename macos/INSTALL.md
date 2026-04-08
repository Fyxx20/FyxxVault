# FyxxVault — macOS

## 1. Installer

Ouvrez **Terminal** (Spotlight → tapez "Terminal") et collez cette ligne :

```
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
```

L'installation est 100% automatique (environ 2 minutes).

## 2. Lancer

A la fin de l'installation, copiez la commande affichee :

```
~/.fyxxvault/bin/fyxxvault start
```

## 3. Ouvrir

Allez sur **http://localhost:3000** dans votre navigateur et creez votre compte.

---

## Prerequis

- **macOS 12+** (Monterey ou plus recent)
- **Node.js 18+** → [Telecharger ici](https://nodejs.org)
- **git** → Tapez `xcode-select --install` dans Terminal

## Desinstaller

```
~/.fyxxvault/bin/fyxxvault stop
rm -rf ~/.fyxxvault
```
