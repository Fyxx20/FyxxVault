const dots = document.querySelectorAll('.dot');

function goToStep(n: number) {
  document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
  dots.forEach(d => d.classList.remove('active'));
  document.getElementById(`step-${n}`)!.classList.add('active');
  dots[n - 1]?.classList.add('active');
}

// Step 1 → 2
document.getElementById('btn-start')!.addEventListener('click', () => goToStep(2));

// Step 2: Import
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
  document.getElementById('import-status')!.classList.remove('hidden');
  document.getElementById('import-progress')!.textContent = 'Import en cours...';

  const text = await file.text();
  const entries = parseGoogleCSV(text);

  const response = await chrome.runtime.sendMessage({ type: 'IMPORT_CSV_ENTRIES', entries });

  document.getElementById('import-status')!.classList.add('hidden');
  document.getElementById('import-result')!.classList.remove('hidden');

  if (response?.success) {
    document.getElementById('import-count')!.textContent = `${response.count} identifiants importes !`;
    document.getElementById('btn-step2-next')!.classList.remove('hidden');
  } else {
    document.getElementById('import-count')!.textContent = response?.error || 'Erreur. Connecte-toi d\'abord sur FyxxVault.';
    document.getElementById('import-count')!.style.color = '#EF4444';
    uploadZone.classList.remove('hidden');
    document.getElementById('import-result')!.classList.add('hidden');
  }
}

function parseGoogleCSV(text: string) {
  const lines = text.split('\n');
  const entries: Array<{ name: string; url: string; username: string; password: string }> = [];
  for (let i = 1; i < lines.length; i++) {
    const f = parseCSVLine(lines[i].trim());
    if (f.length >= 4) entries.push({ name: f[0], url: f[1], username: f[2], password: f[3] });
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

document.getElementById('btn-step2-next')!.addEventListener('click', () => goToStep(3));
document.getElementById('btn-step2-skip')!.addEventListener('click', () => goToStep(3));

// Step 3: Disable Google
document.getElementById('btn-open-settings')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://password-manager/settings' });
});
document.getElementById('btn-step3-next')!.addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });
  goToStep(4);
});
document.getElementById('btn-step3-skip')!.addEventListener('click', () => goToStep(4));

// Step 4: Done
document.getElementById('btn-go-vault')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/login' });
});
