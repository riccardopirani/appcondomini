const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

/** Configurazione SMTP e server (ex .env.example) */
const PORT = Number(process.env.PORT) || 8080;
const SMTP_HOST = 'pro.eu.turbo-smtp.com';
/** Porta 25: SMTP in chiaro, senza TLS/SSL né upgrade STARTTLS */
const SMTP_PORT = 25;
const SMTP_USER = 'f12b7bc7f22c095953eb';
const SMTP_PASSWORD = '4jcwkx5dQl6JzLMib8rB';
const SMTP_FROM = 'no-reply@portobellodigallura.email';

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

const smtpConfig = {
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: false,
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASSWORD,
  },
  /** Non negozia STARTTLS: traffico SMTP solo plaintext */
  ignoreTLS: true,
  connectionTimeout: 10000,
  debugger: true,
  greetingTimeout: 10000,
  socketTimeout: 20000,
};

const transporter = nodemailer.createTransport(smtpConfig);

app.get('/health', (_, res) => {
  res.json({ ok: true, service: 'pdg-email-backend' });
});

app.post('/send-email', async (req, res) => {
  const {
    to,
    subject,
    text,
    html,
    replyTo,
    fromName,
  } = req.body || {};

  if (!to || !subject || (!text && !html)) {
    return res.status(400).json({
      ok: false,
      error: 'Missing required fields: to, subject, text/html',
    });
  }

  const fromAddress = SMTP_FROM;

  try {
    const info = await transporter.sendMail({
      from: `"${fromName || 'pdg'}" <${fromAddress}>`,
      to,
      subject,
      text: text || undefined,
      html: html || undefined,
      replyTo: replyTo || undefined,
    });

    res.json({
      ok: true,
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error?.message || 'SMTP send failed',
    });
  }
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`PDG email backend listening on http://localhost:${PORT}`);
});
