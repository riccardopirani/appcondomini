const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const port = Number(process.env.PORT || 8080);

app.use(cors());
app.use(express.json({ limit: '1mb' }));

const smtpConfig = {
  host: process.env.SMTP_HOST || 'pro.turbo-smtp.com',
  port: Number(process.env.SMTP_PORT || 465),
  secure: (process.env.SMTP_SECURE || 'true') === 'true',
  auth: {
    user: process.env.SMTP_USER || '20ec50606baae0792cfb',
    pass: process.env.SMTP_PASSWORD || 'zaV9ZWPfDHCkMypY8X5I',
  },
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

  const fromAddress =
    process.env.SMTP_FROM || 'no-reply@portobellodigallura.it';

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

app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`PDG email backend listening on http://localhost:${port}`);
});
