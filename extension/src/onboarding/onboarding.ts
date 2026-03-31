// FyxxVault Onboarding

function goToStep(n: number) {
  document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
  document.getElementById(`step-${n}`)!.classList.add('active');
}

// ─── Step 1 → 2 ───
document.getElementById('btn-start')!.addEventListener('click', () => goToStep(2));

// ─── Step 2: Pin + Connect via popup ───
let statusPoll: ReturnType<typeof setInterval> | null = null;

function startStatusPoll() {
  const dot = document.getElementById('status-dot')!;
  const text = document.getElementById('status-text')!;
  const btn = document.getElementById('btn-step2-next') as HTMLButtonElement;

  statusPoll = setInterval(async () => {
    try {
      const status = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });
      if (status?.isUnlocked) {
        dot.classList.add('connected');
        text.textContent = 'Coffre deverrouille !';
        btn.classList.remove('hidden');
        if (statusPoll) { clearInterval(statusPoll); statusPoll = null; }
      } else if (status?.isAuthenticated) {
        dot.classList.add('partial');
        text.textContent = 'Connecte — deverrouille le coffre dans le popup';
      }
    } catch {}
  }, 2000);
}

// Start polling when step 2 is shown
const observer = new MutationObserver(() => {
  if (document.getElementById('step-2')?.classList.contains('active')) {
    startStatusPoll();
  }
});
observer.observe(document.getElementById('step-2')!, { attributes: true, attributeFilter: ['class'] });

// Also check immediately
(async () => {
  try {
    const status = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });
    if (status?.isUnlocked) {
      const dot = document.getElementById('status-dot')!;
      const text = document.getElementById('status-text')!;
      const btn = document.getElementById('btn-step2-next') as HTMLButtonElement;
      dot.classList.add('connected');
      text.textContent = 'Coffre deverrouille !';
      btn.classList.remove('hidden');
    }
  } catch {}
})();

document.getElementById('btn-step2-next')!.addEventListener('click', () => {
  if (statusPoll) { clearInterval(statusPoll); statusPoll = null; }
  goToStep(3);
});
document.getElementById('btn-step2-skip')!.addEventListener('click', () => {
  if (statusPoll) { clearInterval(statusPoll); statusPoll = null; }
  goToStep(3);
});

// ─── Step 3: Import ───
document.getElementById('btn-open-export')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://password-manager/settings' });
});

const uploadZone = document.getElementById('upload-zone')!;
const csvInput = document.getElementById('csv-file') as HTMLInputElement;

uploadZone.addEventListener('click', () => csvInput.click());
uploadZone.addEventListener('dragover', (e) => { e.preventDefault(); uploadZone.classList.add('drag-over'); });
uploadZone.addEventListener('dragleave', () => uploadZone.classList.remove('drag-over'));
uploadZone.addEventListener('drop', (e) => {
  e.preventDefault();
  uploadZone.classList.remove('drag-over');
  const file = e.dataTransfer?.files[0];
  if (file?.name.endsWith('.csv')) processCSV(file);
});
csvInput.addEventListener('change', () => { if (csvInput.files?.[0]) processCSV(csvInput.files[0]); });

async function processCSV(file: File) {
  uploadZone.classList.add('hidden');
  document.getElementById('export-card')!.classList.add('hidden');
  document.getElementById('upload-card')!.classList.add('hidden');
  document.getElementById('import-loading')!.classList.remove('hidden');

  const text = await file.text();
  const entries = parseGoogleCSV(text);

  document.getElementById('import-progress')!.textContent = `${entries.length} identifiants trouves...`;

  const response = await chrome.runtime.sendMessage({ type: 'IMPORT_CSV_ENTRIES', entries });

  document.getElementById('import-loading')!.classList.add('hidden');

  if (response?.success) {
    document.getElementById('import-success')!.classList.remove('hidden');
    document.getElementById('import-count')!.textContent = `${response.count} identifiants importes !`;
    document.getElementById('btn-step3-next')!.classList.remove('hidden');
    document.getElementById('btn-step3-skip')!.classList.add('hidden');
  } else if (response?.needsPro) {
    document.getElementById('pro-popup')!.classList.remove('hidden');
    document.getElementById('btn-step3-skip')!.classList.add('hidden');
  } else {
    // Show error inline
    document.getElementById('export-card')!.classList.remove('hidden');
    document.getElementById('upload-card')!.classList.remove('hidden');
    uploadZone.classList.remove('hidden');

    const errorMsg = response?.error || 'Erreur inconnue';
    if (errorMsg.includes('verrouille') || errorMsg.includes('authentifie')) {
      alert('Connecte-toi et deverrouille ton coffre via le popup de l\'extension (icone en haut a droite), puis reessaye.');
    } else {
      alert('Erreur: ' + errorMsg);
    }
  }
}

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

document.getElementById('btn-step3-next')!.addEventListener('click', () => goToStep(4));
document.getElementById('btn-step3-skip')!.addEventListener('click', () => goToStep(4));

document.getElementById('btn-upgrade-pro')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/vault/settings' });
});
document.getElementById('btn-pro-skip')!.addEventListener('click', () => {
  document.getElementById('pro-popup')!.classList.add('hidden');
  goToStep(4);
});

// ─── Step 4: Disable Google ───
document.getElementById('btn-open-settings')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://password-manager/settings' });
});
document.getElementById('btn-step4-next')!.addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });
  goToStep(5);
});
document.getElementById('btn-step4-skip')!.addEventListener('click', () => goToStep(5));

// ─── Step 5: Done ───
document.getElementById('btn-go-vault')!.addEventListener('click', () => {
  window.close();
});
