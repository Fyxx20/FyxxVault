// FyxxVault Onboarding — wait for DOM
document.addEventListener('DOMContentLoaded', () => {
  init();
});

// Fallback if DOMContentLoaded already fired
if (document.readyState !== 'loading') {
  init();
}

function init() {
  const $ = (id: string) => document.getElementById(id)!;

  function goToStep(n: number) {
    document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
    $(`step-${n}`).classList.add('active');
    // Start polling on step 2
    if (n === 2) startStatusPoll();
  }

  // ─── Step 1 → 2 ───
  $('btn-start').addEventListener('click', () => goToStep(2));

  // ─── Step 2: Pin + Connect via popup ───
  let statusPoll: ReturnType<typeof setInterval> | null = null;

  function startStatusPoll() {
    if (statusPoll) return; // Already polling

    checkStatus(); // Check immediately

    statusPoll = setInterval(checkStatus, 2000);
  }

  async function checkStatus() {
    try {
      const status = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });
      const dot = $('status-dot');
      const text = $('status-text');
      const btn = $('btn-step2-next');

      if (status?.isUnlocked) {
        dot.className = 'status-dot connected';
        text.textContent = 'Coffre deverrouille !';
        btn.classList.remove('hidden');
        if (statusPoll) { clearInterval(statusPoll); statusPoll = null; }
      } else if (status?.isAuthenticated) {
        dot.className = 'status-dot partial';
        text.textContent = 'Connecte — deverrouille le coffre dans le popup';
      }
    } catch {}
  }

  $('btn-step2-next').addEventListener('click', () => {
    if (statusPoll) { clearInterval(statusPoll); statusPoll = null; }
    goToStep(3);
  });

  // ─── Step 3: Import ───
  $('btn-open-export').addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    // chrome:// URLs need to go through the background script
    chrome.runtime.sendMessage({ type: 'OPEN_CHROME_PASSWORDS' });
  });

  const uploadZone = $('upload-zone');
  const csvInput = $('csv-file') as HTMLInputElement;

  uploadZone.addEventListener('click', (e) => {
    e.preventDefault();
    csvInput.click();
  });

  uploadZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    e.stopPropagation();
    uploadZone.classList.add('drag-over');
  });

  uploadZone.addEventListener('dragleave', (e) => {
    e.preventDefault();
    uploadZone.classList.remove('drag-over');
  });

  uploadZone.addEventListener('drop', (e) => {
    e.preventDefault();
    e.stopPropagation();
    uploadZone.classList.remove('drag-over');
    const file = e.dataTransfer?.files[0];
    if (file && (file.name.endsWith('.csv') || file.type === 'text/csv')) {
      processCSV(file);
    }
  });

  csvInput.addEventListener('change', () => {
    if (csvInput.files?.[0]) processCSV(csvInput.files[0]);
  });

  async function processCSV(file: File) {
    uploadZone.classList.add('hidden');
    $('export-card').classList.add('hidden');
    $('upload-card').classList.add('hidden');
    $('import-loading').classList.remove('hidden');

    const text = await file.text();
    const entries = parseGoogleCSV(text);

    $('import-progress').textContent = `${entries.length} identifiants trouves...`;

    const response = await chrome.runtime.sendMessage({ type: 'IMPORT_CSV_ENTRIES', entries });

    $('import-loading').classList.add('hidden');

    if (response?.success) {
      $('import-success').classList.remove('hidden');
      $('import-count').textContent = `${response.count} identifiants importes !`;
      $('btn-step3-next').classList.remove('hidden');
      $('btn-step3-skip').classList.add('hidden');
    } else if (response?.needsPro) {
      $('pro-popup').classList.remove('hidden');
      $('btn-step3-skip').classList.add('hidden');
    } else {
      $('export-card').classList.remove('hidden');
      $('upload-card').classList.remove('hidden');
      uploadZone.classList.remove('hidden');

      const errorMsg = response?.error || 'Erreur inconnue';
      if (errorMsg.includes('verrouille') || errorMsg.includes('authentifie')) {
        alert('Connecte-toi et deverrouille ton coffre via le popup de l\'extension, puis reessaye.');
      } else {
        alert('Erreur: ' + errorMsg);
      }
    }
  }

  $('btn-step3-next').addEventListener('click', () => goToStep(4));
  $('btn-step3-skip').addEventListener('click', () => goToStep(4));

  $('btn-upgrade-pro').addEventListener('click', () => {
    chrome.tabs.create({ url: 'https://fyxxvault.com/vault/settings' });
  });
  $('btn-pro-skip').addEventListener('click', () => {
    $('pro-popup').classList.add('hidden');
    goToStep(4);
  });

  // ─── Step 4: Disable Google ───
  $('btn-open-settings').addEventListener('click', () => {
    chrome.runtime.sendMessage({ type: 'OPEN_CHROME_PASSWORDS' });
  });
  $('btn-step4-next').addEventListener('click', async () => {
    await chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });
    goToStep(5);
  });
  $('btn-step4-skip').addEventListener('click', () => goToStep(5));

  // ─── Step 5: Done ───
  $('btn-go-vault').addEventListener('click', () => {
    window.close();
  });
}

// ─── CSV parsing ───
function parseGoogleCSV(text: string) {
  const lines = text.split('\n');
  const entries: Array<{ name: string; url: string; username: string; password: string }> = [];
  for (let i = 1; i < lines.length; i++) {
    const f = parseCSVLine(lines[i].trim());
    if (f.length >= 4 && f[3]) entries.push({ name: f[0], url: f[1], username: f[2], password: f[3] });
  }
  return entries;
}

function parseCSVLine(line: string) {
  const result: string[] = [];
  let cur = '', inQ = false;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === '"') { if (inQ && line[i+1] === '"') { cur += '"'; i++; } else inQ = !inQ; }
    else if (line[i] === ',' && !inQ) { result.push(cur); cur = ''; }
    else cur += line[i];
  }
  result.push(cur);
  return result;
}
