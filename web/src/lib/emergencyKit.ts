import { jsPDF } from 'jspdf';
import QRCode from 'qrcode';

export async function generateEmergencyPDF(email: string): Promise<Blob> {
	const doc = new jsPDF();
	const now = new Date().toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });

	// Header
	doc.setFontSize(24);
	doc.setFont('helvetica', 'bold');
	doc.text('FyxxVault', 105, 25, { align: 'center' });
	doc.setFontSize(14);
	doc.setFont('helvetica', 'normal');
	doc.text("Kit d'Urgence — Self-Hosted Edition", 105, 35, { align: 'center' });

	// Separator line
	doc.setDrawColor(0, 212, 255);
	doc.setLineWidth(0.5);
	doc.line(20, 42, 190, 42);

	// Date
	doc.setFontSize(11);
	doc.setFont('helvetica', 'normal');
	doc.text(`Date de creation : ${now}`, 20, 55);

	// Email
	doc.text(`Email : ${email}`, 20, 65);

	// Master Password section
	doc.setFontSize(13);
	doc.setFont('helvetica', 'bold');
	doc.text('Master Password', 20, 82);
	doc.setFontSize(10);
	doc.setFont('helvetica', 'normal');
	doc.text('Ecrivez votre Master Password ici a la main :', 20, 92);

	// Box for password
	doc.setDrawColor(100, 100, 100);
	doc.setLineWidth(0.3);
	doc.rect(20, 96, 170, 18);
	doc.setFontSize(8);
	doc.setTextColor(150, 150, 150);
	doc.text('(Ne remplissez ce champ que sur la version papier)', 105, 120, { align: 'center' });
	doc.setTextColor(0, 0, 0);

	// Warning
	doc.setFillColor(255, 240, 240);
	doc.rect(20, 130, 170, 30, 'F');
	doc.setDrawColor(220, 50, 50);
	doc.setLineWidth(0.5);
	doc.rect(20, 130, 170, 30);
	doc.setFontSize(11);
	doc.setFont('helvetica', 'bold');
	doc.setTextColor(200, 30, 30);
	doc.text('ATTENTION', 25, 140);
	doc.setFont('helvetica', 'normal');
	doc.setFontSize(9);
	doc.setTextColor(80, 0, 0);
	doc.text('Conservez ce document dans un lieu sur (coffre-fort physique, enveloppe scellee).', 25, 148);
	doc.text('Ne le stockez PAS sur votre ordinateur. Ne le photographiez pas.', 25, 155);
	doc.setTextColor(0, 0, 0);

	// Instructions
	doc.setFontSize(12);
	doc.setFont('helvetica', 'bold');
	doc.text('Instructions de reinstallation', 20, 175);
	doc.setFontSize(10);
	doc.setFont('helvetica', 'normal');
	doc.text('1. Installez FyxxVault : curl -fsSL https://fyxxvault.com/install.sh | bash', 25, 185);
	doc.text('2. Restaurez votre fichier fyxxvault.db dans ~/.fyxxvault/data/', 25, 193);
	doc.text('3. Lancez le serveur : fyxxvault start', 25, 201);
	doc.text('4. Entrez votre Master Password pour deverrouiller le coffre', 25, 209);

	// QR Code
	try {
		const qrDataUrl = await QRCode.toDataURL('https://github.com/Fyxx20/FyxxVault#self-hosting', {
			width: 120,
			margin: 1,
			color: { dark: '#0a101e', light: '#ffffff' }
		});
		doc.addImage(qrDataUrl, 'PNG', 75, 220, 30, 30);
		doc.setFontSize(8);
		doc.setTextColor(100, 100, 100);
		doc.text('Scannez pour acceder a la documentation', 105, 255, { align: 'center' });
	} catch {
		// QR generation failed — skip silently
	}

	// Final phrase
	doc.setTextColor(0, 0, 0);
	doc.setFontSize(10);
	doc.setFont('helvetica', 'bold');
	doc.text('Ce document est la seule cle de votre vie numerique.', 105, 268, { align: 'center' });
	doc.text('Ne le donnez jamais a personne.', 105, 275, { align: 'center' });

	// Footer
	doc.setFontSize(8);
	doc.setFont('helvetica', 'normal');
	doc.setTextColor(150, 150, 150);
	doc.text('FyxxVault — Vos donnees, votre controle. Open Source, gratuit a vie.', 105, 290, { align: 'center' });

	return doc.output('blob');
}

export function downloadEmergencyPDF(email: string) {
	generateEmergencyPDF(email).then((blob) => {
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = 'FyxxVault-Kit-Urgence.pdf';
		a.click();
		URL.revokeObjectURL(url);
	});
}
