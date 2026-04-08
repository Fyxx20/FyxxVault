#!/usr/bin/env node
import { execSync, spawn } from 'child_process';
import path from 'path';
import os from 'os';
import fs from 'fs';

const FYXX_DIR = path.join(os.homedir(), '.fyxxvault');
const DATA_DIR = path.join(FYXX_DIR, 'data');
const LOG_DIR = path.join(FYXX_DIR, 'logs');
const PID_FILE = path.join(FYXX_DIR, 'fyxxvault.pid');
const LOG_FILE = path.join(LOG_DIR, 'fyxxvault.log');

const command = process.argv[2];

function log(msg) {
  const ts = new Date().toISOString();
  const line = `[${ts}] ${msg}\n`;
  fs.mkdirSync(LOG_DIR, { recursive: true });
  fs.appendFileSync(LOG_FILE, line);
  console.log(msg);
}

function isRunning() {
  if (!fs.existsSync(PID_FILE)) return false;
  const pid = parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());
  try { process.kill(pid, 0); return true; } catch { return false; }
}

function getPid() {
  if (!fs.existsSync(PID_FILE)) return null;
  return parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());
}

const commands = {
  start() {
    if (isRunning()) { log('⚡ FyxxVault is already running (PID: ' + getPid() + ')'); return; }
    const buildDir = path.join(FYXX_DIR, 'app', 'web', 'build');
    if (!fs.existsSync(path.join(buildDir, 'index.js'))) {
      log('❌ Build not found. Run: fyxxvault update'); return;
    }
    const port = process.env.PORT || 3000;
    const child = spawn('node', [path.join(buildDir, 'index.js')], {
      detached: true, stdio: ['ignore', fs.openSync(LOG_FILE, 'a'), fs.openSync(LOG_FILE, 'a')],
      env: { ...process.env, PORT: String(port), FYXXVAULT_DATA_DIR: DATA_DIR }
    });
    fs.writeFileSync(PID_FILE, String(child.pid));
    child.unref();
    log(`🚀 FyxxVault started on port ${port} (PID: ${child.pid})`);
  },
  stop() {
    if (!isRunning()) { log('⏹ FyxxVault is not running'); return; }
    const pid = getPid();
    process.kill(pid, 'SIGTERM');
    fs.unlinkSync(PID_FILE);
    log(`🛑 FyxxVault stopped (PID: ${pid})`);
  },
  restart() { commands.stop(); setTimeout(() => commands.start(), 1000); },
  status() {
    if (isRunning()) {
      log(`✅ FyxxVault is running (PID: ${getPid()})`);
      const dbPath = path.join(DATA_DIR, 'fyxxvault.db');
      if (fs.existsSync(dbPath)) {
        const size = (fs.statSync(dbPath).size / 1024).toFixed(1);
        log(`📦 Database: ${size} KB`);
      }
    } else {
      log('⏹ FyxxVault is not running');
    }
  },
  backup() {
    const dbPath = path.join(DATA_DIR, 'fyxxvault.db');
    if (!fs.existsSync(dbPath)) { log('❌ No database found'); return; }
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = path.join(DATA_DIR, `fyxxvault-backup-${ts}.db`);
    fs.copyFileSync(dbPath, backupPath);
    log(`💾 Backup created: ${backupPath}`);
  },
  async check() {
    try {
      const { default: Database } = await import('better-sqlite3');
      const db = new Database(path.join(DATA_DIR, 'fyxxvault.db'), { readonly: true });
      const result = db.pragma('integrity_check');
      db.close();
      log(`🔍 Integrity: ${result[0].integrity_check}`);
    } catch (e) { log(`❌ Check failed: ${e.message}`); }
  },
  audit() {
    const dbPath = path.join(DATA_DIR, 'fyxxvault.db');
    if (!fs.existsSync(dbPath)) { log('❌ No database found'); return; }
    const stats = fs.statSync(dbPath);
    const mode = '0' + (stats.mode & 0o777).toString(8);
    log(`📋 Database permissions: ${mode}`);
    log(`📋 Database size: ${(stats.size / 1024).toFixed(1)} KB`);
    log(`📋 Last modified: ${stats.mtime.toISOString()}`);
    if (mode !== '0600') log('⚠️  Warning: Database permissions should be 0600');
  },
  uninstall() {
    commands.stop();
    log('🗑️  To fully uninstall, remove ~/.fyxxvault/');
    log('   rm -rf ~/.fyxxvault');
  }
};

// check command needs to be async for dynamic import
if (command === 'check') {
  (async () => { await commands.check(); })();
} else if (commands[command]) {
  commands[command]();
} else {
  console.log(`
  FyxxVault CLI — Self-Hosted Password Manager

  Usage: fyxxvault <command>

  Commands:
    start      Start the server
    stop       Stop the server
    restart    Restart the server
    status     Show server status
    backup     Create database backup
    check      Run integrity check
    audit      Security audit
    uninstall  Uninstall instructions
  `);
}
