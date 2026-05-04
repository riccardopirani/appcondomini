const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

/** Configurazione SMTP e server (ex .env.example) */
const PORT = 8080;
const SMTP_HOST =  'smtp.turbo-smtp.com';
/** 587 = submission senza TLS implicito (SMTPS); la sessione passa a TLS via STARTTLS. */
const SMTP_PORT = 587;
const SMTP_SECURE = false;
const SMTP_USER = '20ec50606baae0792cfb';
const SMTP_PASSWORD = 'zaV9ZWPfDHCkMypY8X5I';
const SMTP_FROM = 'no-reply@portobellodigallura.email';

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

const smtpConfig = {
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: SMTP_SECURE,
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASSWORD,
  },
  requireTLS: true,

  tls: {

    rejectUnauthorized: false,

  },

  connectionTimeout: 10000,

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
