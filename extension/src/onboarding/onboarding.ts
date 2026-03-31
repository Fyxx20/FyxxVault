// FyxxVault Onboarding

const dots = document.querySelectorAll('.dot');

function goToStep(n: number) {
  document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
  dots.forEach(d => d.classList.remove('active'));
  document.getElementById(`step-${n}`)!.classList.add('active');
  dots[n - 1]?.classList.add('active');
}

// ─── Step 1 → 2 ───
document.getElementById('btn-start')!.addEventListener('click', () => goToStep(2));

// ─── Step 2 → 3 ───
document.getElementById('btn-step2-next')!.addEventListener('click', () => goToStep(3));
document.getElementById('btn-step2-skip')!.addEventListener('click', () => goToStep(3));

// ─── Step 3: Export Google passwords ───
document.getElementById('btn-open-export')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://password-manager/settings' });
});
document.getElementById('btn-step3-next')!.addEventListener('click', () => goToStep(4));
document.getElementById('btn-step3-skip')!.addEventListener('click', () => goToStep(4));

// ─── Step 4: Import CSV into FyxxVault ───
const uploadZone = document.getElementById('upload-zone')!;
const csvInput = document.getElementById('csv-file') as HTMLInputElement;
const importStatus = document.getElementById('import-status')!;
const importProgress = document.getElementById('import-progress')!;
const importResult = document.getElementById('import-result')!;
const importCount = document.getElementById('import-count')!;
const btnStep4Next = document.getElementById('btn-step4-next')!;

uploadZone.addEventListener('click', () => csvInput.click());

uploadZone.addEventListener('dragover', (e) => {
  e.preventDefault();
  uploadZone.classList.add('drag-over');
});

uploadZone.addEventListener('dragleave', () => {
  uploadZone.classList.remove('drag-over');
});

uploadZone.addEventListener('drop', (e) => {
  e.preventDefault();
  uploadZone.classList.remove('drag-over');
  const file = e.dataTransfer?.files[0];
  if (file && file.name.endsWith('.csv')) {
    processCSV(file);
  }
});

csvInput.addEventListener('change', () => {
  const file = csvInput.files?.[0];
  if (file) processCSV(file);
});

async function processCSV(file: File) {
  uploadZone.classList.add('hidden');
  importStatus.classList.remove('hidden');
  importProgress.textContent = 'Lecture du fichier...';

  const text = await file.text();
  const entries = parseGoogleCSV(text);

  importProgress.textContent = `${entries.length} identifiants trouves. Import en cours...`;

  // Send to service worker for encryption and storage
  const response = await chrome.runtime.sendMessage({
    type: 'IMPORT_CSV_ENTRIES',
    entries
  });

  importStatus.classList.add('hidden');
  importResult.classList.remove('hidden');

  if (response?.success) {
    importCount.textContent = `${response.count} identifiants importes dans FyxxVault !`;
    btnStep4Next.classList.remove('hidden');
  } else {
    importCount.textContent = response?.error || 'Erreur lors de l\'import. Connecte-toi d\'abord sur FyxxVault.';
    uploadZone.classList.remove('hidden');
    importResult.classList.add('hidden');
  }
}

function parseGoogleCSV(text: string): Array<{ name: string; url: string; username: string; password: string }> {
  const lines = text.split('\n');
  if (lines.length < 2) return [];

  // Google Chrome CSV format: name,url,username,password
  // or: name,url,username,password,note
  const entries: Array<{ name: string; url: string; username: string; password: string }> = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    // Parse CSV with possible quoted fields
    const fields = parseCSVLine(line);
    if (fields.length >= 4) {
      entries.push({
        name: fields[0],
        url: fields[1],
        username: fields[2],
        password: fields[3]
      });
    }
  }

  return entries;
}

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

document.getElementById('btn-step4-next')!.addEventListener('click', () => goToStep(5));
document.getElementById('btn-step4-skip')!.addEventListener('click', () => goToStep(5));

// ─── Step 5: Delete Google passwords ───
document.getElementById('btn-open-delete')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://password-manager/passwords' });
});

const confirmCheckbox = document.getElementById('confirm-deleted') as HTMLInputElement;
const btnStep5Next = document.getElementById('btn-step5-next') as HTMLButtonElement;

confirmCheckbox.addEventListener('change', () => {
  btnStep5Next.disabled = !confirmCheckbox.checked;
  btnStep5Next.classList.toggle('disabled', !confirmCheckbox.checked);
});

btnStep5Next.addEventListener('click', async () => {
  // Disable Chrome password saving for good
  await chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });
  goToStep(6);
});

// ─── Step 6: Open vault ───
document.getElementById('btn-go-vault')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/login' });
});
