import PostalMime from 'postal-mime';

export default {
  async email(message: ForwardableEmailMessage) {
    try {
      const rawEmail = new Response(message.raw);
      const arrayBuffer = await rawEmail.arrayBuffer();
      const parser = new PostalMime();
      const parsed = await parser.parse(arrayBuffer);

      await fetch('https://fyxxvault.com/api/email/inbound', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          secret: 'fv-inbound-b47bb7fd79e676b0ba38c9f35b8f8477',
          to: message.to,
          from: message.from,
          from_name: parsed.from?.name || '',
          subject: parsed.subject || '',
          text: parsed.text || '',
          html: parsed.html || ''
        })
      });
    } catch (error) {
      console.error('Email processing failed:', error);
    }
  }
};
