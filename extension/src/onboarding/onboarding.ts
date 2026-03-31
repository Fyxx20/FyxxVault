// FyxxVault Onboarding

let currentStep = 1;

const steps = [
  document.getElementById('step-1')!,
  document.getElementById('step-2')!,
  document.getElementById('step-3')!,
  document.getElementById('step-4')!,
];

const dots = document.querySelectorAll('.dot');

function goToStep(n: number) {
  steps.forEach(s => s.classList.remove('active'));
  dots.forEach(d => d.classList.remove('active'));
  currentStep = n;
  steps[n - 1].classList.add('active');
  dots[n - 1].classList.add('active');
}

// Step 1 → 2
document.getElementById('btn-start')!.addEventListener('click', () => goToStep(2));

// Step 2 → 3
document.getElementById('btn-step2-next')!.addEventListener('click', () => goToStep(3));

// Step 3: Disable Google password manager
document.getElementById('btn-disable-google')!.addEventListener('click', async () => {
  const btn = document.getElementById('btn-disable-google') as HTMLButtonElement;
  const hint = document.getElementById('disable-hint')!;
  const status = document.getElementById('google-status')!;
  const successCard = document.getElementById('success-card')!;

  btn.textContent = 'Desactivation...';
  btn.disabled = true;

  try {
    // Send message to service worker to disable Chrome's password manager
    const response = await chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });

    if (response?.success) {
      btn.classList.add('hidden');
      status.textContent = 'Desactive';
      status.classList.add('done');
      successCard.classList.remove('hidden');
      hint.textContent = '';
    } else {
      btn.textContent = 'Reessayer';
      btn.disabled = false;
      hint.textContent = response?.error || 'Erreur. Essaie de desactiver manuellement dans chrome://settings/passwords';
    }
  } catch {
    btn.textContent = 'Reessayer';
    btn.disabled = false;
    hint.textContent = 'Erreur de communication avec l\'extension.';
  }
});

// Step 3 → 4
document.getElementById('btn-finish')!.addEventListener('click', () => goToStep(4));

// Step 4: Open vault
document.getElementById('btn-go-vault')!.addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/login' });
});
