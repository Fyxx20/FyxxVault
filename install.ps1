# ═══════════════════════════════════════════════════
#  FyxxVault Installer — Windows Edition
#  One command. Full control.
# ═══════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

# ── Config ──
$FYXX_DIR = "$env:USERPROFILE\.fyxxvault"
$APP_DIR = "$FYXX_DIR\app"
$DATA_DIR = "$FYXX_DIR\data"
$LOG_DIR = "$FYXX_DIR\logs"
$BIN_DIR = "$FYXX_DIR\bin"
$REPO = "https://github.com/Fyxx20/FyxxVault.git"
$BRANCH = "main"
$PORT = if ($env:FYXXVAULT_PORT) { $env:FYXXVAULT_PORT } else { "3000" }
$TOTAL_STEPS = 7
$CURRENT_STEP = 0

# ═══════════════════════════════════════════════════
#  UI
# ═══════════════════════════════════════════════════

function Write-Cyan { param($Text) Write-Host $Text -ForegroundColor Cyan -NoNewline }
function Write-Violet { param($Text) Write-Host $Text -ForegroundColor Magenta -NoNewline }
function Write-Ok { param($Text) Write-Host $Text -ForegroundColor Green -NoNewline }
function Write-Err { param($Text) Write-Host $Text -ForegroundColor Red -NoNewline }
function Write-Warn { param($Text) Write-Host $Text -ForegroundColor Yellow -NoNewline }
function Write-Dim { param($Text) Write-Host $Text -ForegroundColor DarkGray -NoNewline }

function Show-Logo {
    Clear-Host
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "================================================================"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "|"; Write-Host "                                                              " -NoNewline; Write-Cyan "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "|"; Write-Host "        " -NoNewline
    Write-Host "FYXX" -ForegroundColor White -NoNewline
    Write-Host "VAULT" -ForegroundColor Cyan -NoNewline
    Write-Host "  " -NoNewline
    Write-Dim "--- Self-Hosted Edition"
    Write-Host "              " -NoNewline; Write-Cyan "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "|"; Write-Host "                                                              " -NoNewline; Write-Cyan "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "================================================================"
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Dim "Your passwords. Your server. Your rules."
    Write-Host ""
    Write-Host ""
    Start-Sleep -Milliseconds 300
}

function Show-Step {
    param($Name)
    $script:CURRENT_STEP++
    $pct = [math]::Floor($CURRENT_STEP * 100 / $TOTAL_STEPS)
    $dots = ""
    for ($i = 1; $i -le $TOTAL_STEPS; $i++) {
        if ($i -le $CURRENT_STEP) { $dots += "# " }
        elseif ($i -eq ($CURRENT_STEP + 1)) { $dots += "> " }
        else { $dots += "- " }
    }
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "$dots"; Write-Dim " ${pct}%"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Host "$Name" -ForegroundColor White
    Write-Host "    " -NoNewline; Write-Dim "------------------------------------------------"
    Write-Host ""
}

function Show-Success { param($Msg) Write-Host "    " -NoNewline; Write-Ok "[OK]  "; Write-Host $Msg }
function Show-Fail { param($Msg) Write-Host "    " -NoNewline; Write-Err "[!!]  "; Write-Host $Msg }
function Show-Info { param($Msg) Write-Host "    " -NoNewline; Write-Dim "      $Msg" }

# ═══════════════════════════════════════════════════
#  Steps
# ═══════════════════════════════════════════════════

function Test-Requirements {
    Show-Step "Checking requirements"

    # Node.js
    try {
        $nodeVersion = (node -v 2>$null).TrimStart('v')
        $nodeMajor = [int]($nodeVersion.Split('.')[0])
        if ($nodeMajor -ge 18) {
            Show-Success "Node.js v$nodeVersion"
        } else {
            Show-Fail "Node.js v$nodeVersion (need 18+)"
            Write-Host ""
            Write-Host "    " -NoNewline; Write-Warn "Install Node.js 18+: https://nodejs.org"
            Write-Host ""
            exit 1
        }
    } catch {
        Show-Fail "Node.js not found"
        Write-Host ""
        Write-Host "    " -NoNewline; Write-Warn "Install Node.js: https://nodejs.org"
        Write-Host ""
        exit 1
    }

    # npm
    try {
        $npmVersion = npm -v 2>$null
        Show-Success "npm v$npmVersion"
    } catch {
        Show-Fail "npm not found"
        exit 1
    }

    # git
    try {
        $gitVersion = (git --version 2>$null) -replace 'git version ', ''
        Show-Success "git v$gitVersion"
    } catch {
        Show-Fail "git not found"
        Write-Host ""
        Write-Host "    " -NoNewline; Write-Warn "Install git: https://git-scm.com"
        Write-Host ""
        exit 1
    }

    # Disk space
    $drive = (Get-Item $env:USERPROFILE).PSDrive
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    Show-Success "Disk space: ${freeGB} GB free"
}

function New-Directories {
    Show-Step "Creating directory structure"

    $dirs = @(
        @($FYXX_DIR, "~\.fyxxvault\"),
        @($APP_DIR, "~\.fyxxvault\app\"),
        @($DATA_DIR, "~\.fyxxvault\data\"),
        @($LOG_DIR, "~\.fyxxvault\logs\"),
        @($BIN_DIR, "~\.fyxxvault\bin\")
    )

    foreach ($d in $dirs) {
        New-Item -ItemType Directory -Path $d[0] -Force | Out-Null
        Show-Success $d[1]
        Start-Sleep -Milliseconds 50
    }
}

function Get-FyxxVault {
    Show-Step "Downloading FyxxVault"

    if (Test-Path "$APP_DIR\.git") {
        Write-Host "    " -NoNewline; Write-Cyan "..."; Write-Host "  Updating to latest version"
        Push-Location $APP_DIR
        git fetch origin $BRANCH --quiet 2>$null
        git reset --hard "origin/$BRANCH" --quiet 2>$null
        Pop-Location
        Show-Success "Updated to latest version"
    } else {
        if (Test-Path $APP_DIR) { Remove-Item -Recurse -Force $APP_DIR; New-Item -ItemType Directory -Path $APP_DIR -Force | Out-Null }
        Write-Host "    " -NoNewline; Write-Cyan "..."; Write-Host "  Cloning repository"
        git clone --branch $BRANCH --depth 1 --quiet $REPO $APP_DIR 2>$null
        Show-Success "Downloaded"
    }

    Show-Info "web/           SvelteKit application"
    Show-Info "extension/     Chrome extension"
    Show-Info "self-hosted/   CLI & scripts"
}

function Install-Dependencies {
    Show-Step "Installing dependencies"

    Write-Host "    " -NoNewline; Write-Cyan "..."; Write-Host "  Installing npm packages (this may take a minute)"
    Push-Location "$APP_DIR\web"
    npm install --silent --no-fund --no-audit 2>$null | Out-Null
    Pop-Location
    Show-Success "Dependencies installed"

    $pkgCount = (Get-ChildItem "$APP_DIR\web\node_modules" -Directory).Count
    Show-Info "$pkgCount packages installed"
}

function Build-Application {
    Show-Step "Building application"

    Show-Info "Compiling SvelteKit with adapter-node..."
    Push-Location "$APP_DIR\web"
    npm run build 2>$null | Out-Null
    Pop-Location
    Show-Success "Build complete"

    if (Test-Path "$APP_DIR\web\build") {
        $buildSize = [math]::Round((Get-ChildItem "$APP_DIR\web\build" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        Show-Info "Build output: ${buildSize} MB"
    }
}

function Initialize-Database {
    Show-Step "Initializing database"

    Write-Host "    " -NoNewline; Write-Cyan "..."; Write-Host "  Creating SQLite database"
    Push-Location $APP_DIR
    node self-hosted/scripts/init-db.js 2>$null
    Pop-Location

    if (Test-Path "$DATA_DIR\fyxxvault.db") {
        $dbSize = [math]::Round((Get-Item "$DATA_DIR\fyxxvault.db").Length / 1KB, 1)
        Show-Info "Database: ${dbSize} KB"
        Show-Info "Location: ~\.fyxxvault\data\fyxxvault.db"
        Show-Info "Mode: WAL (Write-Ahead Logging)"
    }
}

function Install-CLI {
    Show-Step "Setting up CLI"

    # Create fyxxvault.cmd
    $cmdContent = @"
@echo off
set FYXXVAULT_DATA_DIR=%USERPROFILE%\.fyxxvault\data
node "%USERPROFILE%\.fyxxvault\app\self-hosted\bin\fyxxvault.js" %*
"@
    Set-Content -Path "$BIN_DIR\fyxxvault.cmd" -Value $cmdContent
    Show-Success "CLI tool installed (fyxxvault.cmd)"

    # Create panel launcher
    $panelContent = @"
@echo off
set FYXXVAULT_DATA_DIR=%USERPROFILE%\.fyxxvault\data
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.fyxxvault\app\panel.ps1"
"@
    Set-Content -Path "$BIN_DIR\fyxxvault-panel.cmd" -Value $panelContent
    Show-Success "Panel launcher installed"

    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*fyxxvault\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$BIN_DIR;$currentPath", "User")
        $env:Path = "$BIN_DIR;$env:Path"
        Show-Success "Added to PATH"
    } else {
        Show-Success "Already in PATH"
    }
}

# ═══════════════════════════════════════════════════
#  Finish
# ═══════════════════════════════════════════════════

function Show-Finish {
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Ok "================================================================"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Ok "|"; Write-Host "                                                              " -NoNewline; Write-Ok "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Ok "|"; Write-Host "     " -NoNewline; Write-Ok "[OK]"; Write-Host "  Installation complete!                          " -NoNewline; Write-Ok "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Ok "|"; Write-Host "                                                              " -NoNewline; Write-Ok "|"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Ok "================================================================"
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Host "Get started" -ForegroundColor White
    Write-Host "    ------------------------------------------------"
    Write-Host ""
    Write-Host "    1. Start the server:"
    Write-Host "       " -NoNewline; Write-Cyan "fyxxvault start"
    Write-Host ""
    Write-Host ""
    Write-Host "    2. Open in your browser:"
    Write-Host "       " -NoNewline; Write-Cyan "http://localhost:$PORT"
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Host "Useful commands" -ForegroundColor White
    Write-Host "    ------------------------------------------------"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "fyxxvault start"; Write-Dim "        Start the server"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "fyxxvault stop"; Write-Dim "         Stop the server"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "fyxxvault status"; Write-Dim "       Server status"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Cyan "fyxxvault backup"; Write-Dim "       Backup database"
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Dim "Data:  ~\.fyxxvault\data\fyxxvault.db"
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Dim "Logs:  ~\.fyxxvault\logs\fyxxvault.log"
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Violet "Your passwords. Your server. Your rules."
    Write-Host ""
    Write-Host ""
    Write-Host "    " -NoNewline; Write-Warn "!"; Write-Host "  Restart your terminal for CLI access"
    Write-Host ""
}

# ═══════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════

Show-Logo
Test-Requirements
New-Directories
Get-FyxxVault
Install-Dependencies
Build-Application
Initialize-Database
Install-CLI
Show-Finish
