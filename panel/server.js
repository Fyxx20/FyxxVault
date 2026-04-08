#!/usr/bin/env node
import http from 'http';
import { spawn } from 'child_process';
import path from 'path';
import os from 'os';
import fs from 'fs';

const PANEL_PORT = 3001;
const VAULT_PORT = 3000;
const FYXX_DIR = path.join(os.homedir(), '.fyxxvault');
const DATA_DIR = path.join(FYXX_DIR, 'data');
const LOG_DIR = path.join(FYXX_DIR, 'logs');
const PID_FILE = path.join(FYXX_DIR, 'fyxxvault.pid');
const LOG_FILE = path.join(LOG_DIR, 'fyxxvault.log');

// ─── Process helpers ───

function isRunning() {
  if (!fs.existsSync(PID_FILE)) return false;
  const pid = parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());
  try { process.kill(pid, 0); return true; } catch { return false; }
}

function getPid() {
  if (!fs.existsSync(PID_FILE)) return null;
  return parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());
}

function getDbSize() {
  const dbPath = path.join(DATA_DIR, 'fyxxvault.db');
  if (!fs.existsSync(dbPath)) return 0;
  return fs.statSync(dbPath).size;
}

function startServer() {
  if (isRunning()) return { ok: false, error: 'already_running', pid: getPid() };

  // Try build dir first (production), then dev
  const buildDir = path.join(FYXX_DIR, 'app', 'web', 'build');
  const devDir = path.join(process.cwd(), '..', 'web');

  let child;

  if (fs.existsSync(path.join(buildDir, 'index.js'))) {
    // Production mode
    fs.mkdirSync(LOG_DIR, { recursive: true });
    child = spawn('node', [path.join(buildDir, 'index.js')], {
      detached: true,
      stdio: ['ignore', fs.openSync(LOG_FILE, 'a'), fs.openSync(LOG_FILE, 'a')],
      env: { ...process.env, PORT: String(VAULT_PORT), FYXXVAULT_DATA_DIR: DATA_DIR }
    });
  } else if (fs.existsSync(path.join(devDir, 'package.json'))) {
    // Dev mode — use npm run dev
    fs.mkdirSync(LOG_DIR, { recursive: true });
    child = spawn('npx', ['vite', 'dev', '--port', String(VAULT_PORT)], {
      detached: true,
      cwd: devDir,
      stdio: ['ignore', fs.openSync(LOG_FILE, 'a'), fs.openSync(LOG_FILE, 'a')],
      env: { ...process.env, PORT: String(VAULT_PORT), FYXXVAULT_DATA_DIR: DATA_DIR }
    });
  } else {
    return { ok: false, error: 'no_build' };
  }

  fs.writeFileSync(PID_FILE, String(child.pid));
  child.unref();
  return { ok: true, pid: child.pid };
}

function stopServer() {
  if (!isRunning()) return { ok: false, error: 'not_running' };
  const pid = getPid();
  try {
    process.kill(pid, 'SIGTERM');
    // Also kill child processes (the node server spawns children)
    try { process.kill(-pid, 'SIGTERM'); } catch {}
  } catch {}
  if (fs.existsSync(PID_FILE)) fs.unlinkSync(PID_FILE);
  return { ok: true, pid };
}

function getStatus() {
  const running = isRunning();
  return {
    running,
    pid: running ? getPid() : null,
    port: VAULT_PORT,
    dbSize: getDbSize(),
    uptime: running ? process.uptime() : 0
  };
}

// ─── HTML UI ───

function getHTML() {
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FyxxVault — Panel</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
  <style>
    :root {
      --abyss: #0a101e;
      --obsidian: #10182a;
      --cyan: #00d4ff;
      --violet: #8a5cf6;
      --success: #34d399;
      --danger: #ef4444;
      --smoke: #788aa0;
      --ash: #465264;
      --mist: #b4c3d7;
      --silver: #dce4f0;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--abyss);
      color: var(--silver);
      font-family: 'Inter', -apple-system, sans-serif;
      -webkit-font-smoothing: antialiased;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }

    .container { width: 100%; max-width: 480px; }

    /* Header */
    .header {
      text-align: center;
      margin-bottom: 32px;
      animation: fadeIn 0.5s ease;
    }
    .logo {
      width: 56px; height: 56px;
      border-radius: 18px;
      background: linear-gradient(135deg, var(--cyan), var(--violet));
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 16px;
      box-shadow: 0 0 30px rgba(0, 212, 255, 0.25);
    }
    .header h1 { font-size: 22px; font-weight: 800; color: white; }
    .header p { font-size: 13px; color: var(--smoke); margin-top: 4px; }

    /* Status card */
    .status-card {
      background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 20px;
      padding: 28px;
      margin-bottom: 16px;
      backdrop-filter: blur(16px);
      animation: fadeIn 0.5s ease 0.1s both;
    }
    .status-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .status-left { display: flex; align-items: center; gap: 16px; }
    .status-orb {
      width: 52px; height: 52px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.3s;
    }
    .status-orb.on { background: rgba(52, 211, 153, 0.1); }
    .status-orb.off { background: rgba(239, 68, 68, 0.08); }
    .status-dot {
      width: 14px; height: 14px;
      border-radius: 50%;
      transition: all 0.3s;
    }
    .status-dot.on {
      background: var(--success);
      box-shadow: 0 0 14px rgba(52, 211, 153, 0.5);
      animation: pulse 2s ease-in-out infinite;
    }
    .status-dot.off {
      background: var(--danger);
      opacity: 0.5;
    }
    .status-info h2 { font-size: 16px; font-weight: 700; color: white; }
    .status-info .meta { font-size: 12px; color: var(--smoke); margin-top: 2px; }
    .status-info .meta code {
      color: var(--cyan);
      background: rgba(0,212,255,0.08);
      padding: 1px 6px;
      border-radius: 4px;
      font-size: 11px;
    }

    .badge {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .badge.on { background: rgba(52,211,153,0.12); color: var(--success); }
    .badge.off { background: rgba(239,68,68,0.12); color: var(--danger); }

    /* Power button */
    .power-btn {
      width: 56px; height: 56px;
      border-radius: 16px;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.25s;
    }
    .power-btn svg { transition: all 0.2s; }
    .power-btn.start {
      background: rgba(52, 211, 153, 0.1);
      border: 1px solid rgba(52, 211, 153, 0.25);
      color: var(--success);
    }
    .power-btn.start:hover {
      background: rgba(52, 211, 153, 0.2);
      transform: scale(1.05);
      box-shadow: 0 0 24px rgba(52, 211, 153, 0.2);
    }
    .power-btn.stop {
      background: rgba(239, 68, 68, 0.1);
      border: 1px solid rgba(239, 68, 68, 0.25);
      color: var(--danger);
    }
    .power-btn.stop:hover {
      background: rgba(239, 68, 68, 0.2);
      transform: scale(1.05);
      box-shadow: 0 0 24px rgba(239, 68, 68, 0.2);
    }
    .power-btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none !important; box-shadow: none !important; }
    .power-btn .spinner {
      width: 20px; height: 20px;
      border: 2px solid rgba(255,255,255,0.2);
      border-top-color: white;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }

    /* Stats */
    .stats {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-bottom: 16px;
      animation: fadeIn 0.5s ease 0.2s both;
    }
    .stat {
      background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 14px;
      padding: 14px;
    }
    .stat-label { font-size: 10px; color: var(--ash); text-transform: uppercase; letter-spacing: 1px; font-weight: 600; }
    .stat-value { font-size: 20px; font-weight: 800; color: white; margin-top: 4px; }

    /* Open button */
    .open-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      width: 100%;
      padding: 16px;
      border-radius: 16px;
      background: linear-gradient(135deg, var(--cyan), var(--violet));
      color: white;
      font-weight: 700;
      font-size: 14px;
      border: none;
      cursor: pointer;
      transition: all 0.25s;
      position: relative;
      overflow: hidden;
      animation: fadeIn 0.5s ease 0.3s both;
    }
    .open-btn::after {
      content: '';
      position: absolute;
      inset: 0;
      background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.15) 50%, transparent 60%);
      background-size: 200% 100%;
      animation: shimmer 3s ease-in-out infinite;
    }
    .open-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0, 212, 255, 0.3); }
    .open-btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; box-shadow: none; }

    /* Footer */
    .footer {
      text-align: center;
      margin-top: 24px;
      font-size: 10px;
      color: var(--ash);
      animation: fadeIn 0.5s ease 0.4s both;
    }

    /* Toast */
    .toast {
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 20px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 600;
      backdrop-filter: blur(16px);
      border: 1px solid;
      animation: slideIn 0.3s ease;
      z-index: 100;
    }
    .toast.success { background: rgba(52,211,153,0.9); border-color: rgba(52,211,153,0.3); color: white; }
    .toast.error { background: rgba(239,68,68,0.9); border-color: rgba(239,68,68,0.3); color: white; }
    .toast.hide { animation: slideOut 0.3s ease forwards; }

    @keyframes pulse {
      0%, 100% { box-shadow: 0 0 14px rgba(52,211,153,0.3); transform: scale(1); }
      50% { box-shadow: 0 0 22px rgba(52,211,153,0.6); transform: scale(1.15); }
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
    @keyframes slideIn { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }
    @keyframes slideOut { to { opacity: 0; transform: translateX(20px); } }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
      </div>
      <h1>FyxxVault</h1>
      <p>Panneau de controle</p>
    </div>

    <div class="status-card">
      <div class="status-row">
        <div class="status-left">
          <div class="status-orb" id="orb">
            <div class="status-dot" id="dot"></div>
          </div>
          <div class="status-info">
            <h2>Serveur</h2>
            <div class="meta" id="meta">Chargement...</div>
          </div>
        </div>
        <button class="power-btn" id="powerBtn" disabled>
          <div class="spinner"></div>
        </button>
      </div>
    </div>

    <div class="stats" id="stats" style="display:none;">
      <div class="stat">
        <div class="stat-label">Port</div>
        <div class="stat-value" id="statPort">—</div>
      </div>
      <div class="stat">
        <div class="stat-label">PID</div>
        <div class="stat-value" id="statPid">—</div>
      </div>
      <div class="stat">
        <div class="stat-label">Base de donnees</div>
        <div class="stat-value" id="statDb">—</div>
      </div>
      <div class="stat">
        <div class="stat-label">Statut</div>
        <div class="stat-value"><span class="badge" id="badgeStatus">—</span></div>
      </div>
    </div>

    <button class="open-btn" id="openBtn" disabled onclick="window.open('http://localhost:${VAULT_PORT}', '_blank')">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><path d="M15 3h6v6"/><path d="M10 14L21 3"/></svg>
      Ouvrir FyxxVault
    </button>

    <div class="footer">
      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display:inline;vertical-align:middle;"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
      Panel sur :${PANEL_PORT} &middot; Serveur sur :${VAULT_PORT}
    </div>
  </div>

  <div id="toastContainer"></div>

  <script>
    let loading = false;

    function formatBytes(b) {
      if (!b) return '0 KB';
      if (b < 1024) return b + ' B';
      if (b < 1048576) return (b/1024).toFixed(1) + ' KB';
      return (b/1048576).toFixed(1) + ' MB';
    }

    function toast(msg, type = 'success') {
      const el = document.createElement('div');
      el.className = 'toast ' + type;
      el.textContent = msg;
      document.getElementById('toastContainer').appendChild(el);
      setTimeout(() => { el.classList.add('hide'); setTimeout(() => el.remove(), 300); }, 3000);
    }

    function render(data) {
      const { running, pid, port, dbSize } = data;
      const orb = document.getElementById('orb');
      const dot = document.getElementById('dot');
      const meta = document.getElementById('meta');
      const btn = document.getElementById('powerBtn');
      const stats = document.getElementById('stats');
      const openBtn = document.getElementById('openBtn');

      orb.className = 'status-orb ' + (running ? 'on' : 'off');
      dot.className = 'status-dot ' + (running ? 'on' : 'off');

      if (running) {
        meta.innerHTML = 'Port <code>' + port + '</code> &middot; PID <code>' + pid + '</code>';
        btn.className = 'power-btn stop';
        btn.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/></svg>';
        btn.onclick = () => action('stop');
        stats.style.display = 'grid';
        openBtn.disabled = false;
      } else {
        meta.innerHTML = 'Arrete — pret a demarrer';
        btn.className = 'power-btn start';
        btn.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
        btn.onclick = () => action('start');
        stats.style.display = 'none';
        openBtn.disabled = true;
      }
      btn.disabled = loading;

      document.getElementById('statPort').textContent = port;
      document.getElementById('statPid').textContent = pid || '—';
      document.getElementById('statDb').textContent = formatBytes(dbSize);
      const badge = document.getElementById('badgeStatus');
      badge.className = 'badge ' + (running ? 'on' : 'off');
      badge.textContent = running ? 'En ligne' : 'Arrete';
    }

    async function refresh() {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        render(data);
      } catch (e) {
        console.error(e);
      }
    }

    async function action(type) {
      loading = true;
      const btn = document.getElementById('powerBtn');
      btn.disabled = true;
      btn.innerHTML = '<div class="spinner"></div>';

      try {
        const res = await fetch('/api/' + type, { method: 'POST' });
        const data = await res.json();
        if (data.ok) {
          toast(type === 'start' ? 'Serveur demarre' : 'Serveur arrete');
          // Wait a bit for the process to start/stop
          setTimeout(refresh, type === 'start' ? 2000 : 500);
        } else {
          toast(data.error === 'already_running' ? 'Deja en ligne' : data.error === 'not_running' ? 'Deja arrete' : (data.error || 'Erreur'), 'error');
          refresh();
        }
      } catch (e) {
        toast('Erreur: ' + e.message, 'error');
        refresh();
      } finally {
        loading = false;
      }
    }

    refresh();
    setInterval(refresh, 5000);
  </script>
</body>
</html>`;
}

// ─── HTTP Server ───

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PANEL_PORT}`);

  // CORS for same-machine access
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.method === 'GET' && url.pathname === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(getHTML());
  }
  else if (req.method === 'GET' && url.pathname === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(getStatus()));
  }
  else if (req.method === 'POST' && url.pathname === '/api/start') {
    const result = startServer();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(result));
  }
  else if (req.method === 'POST' && url.pathname === '/api/stop') {
    const result = stopServer();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(result));
  }
  else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(PANEL_PORT, () => {
  console.log(`\n  ⚡ FyxxVault Panel running on http://localhost:${PANEL_PORT}\n`);
});
