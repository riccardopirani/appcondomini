const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

/** Configurazione SMTP e server (ex .env.example) */
const PORT = Number(process.env.PORT) || 8080;
const SMTP_HOST = 'pro.eu.turbo-smtp.com';
/** Porta 465: SMTP con SSL/TLS implicito */
const SMTP_PORT = 465;
const SMTP_USER = 'eb76d2df1111fe69401d';
const SMTP_PASSWORD = 'hCaVAzwHPRJXlkMcU2fd';
const SMTP_FROM = 'no-reply@portobellodigallura.email';

const app = express();
let requestCounter = 0;

app.use(cors());
app.use(express.json({ limit: '1mb' }));

function nowIso() {
  return new Date().toISOString();
}

const smtpConfig = {
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: true,
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASSWORD,
  },
  logger: true,
  debug: true,
  connectionTimeout: 15000,
  greetingTimeout: 15000,
  socketTimeout: 30000,
};

const transporter = nodemailer.createTransport(smtpConfig);

app.use((req, _res, next) => {
  console.log(
    `[${nowIso()}] [http] ${req.method} ${req.originalUrl} ip=${req.ip} ua="${req.get(
      'user-agent',
    ) || 'n/a'}"`,
  );
  next();
});

app.get('/health', (_, res) => {
  res.json({ ok: true, service: 'pdg-email-backend' });
});

app.post('/send-email', async (req, res) => {
  const requestId = `mail-${Date.now()}-${++requestCounter}`;
  const startMs = Date.now();
  const {
    to,
    subject,
    text,
    html,
    replyTo,
    fromName,
  } = req.body || {};

  console.log(
    `[${nowIso()}] [${requestId}] payload to=${to || 'missing'} subject="${
      subject || 'missing'
    }" text=${Boolean(text)} html=${Boolean(html)} replyTo=${Boolean(replyTo)} fromName="${
      fromName || 'pdg'
    }"`,
  );

  if (!to || !subject || (!text && !html)) {
    console.warn(`[${nowIso()}] [${requestId}] rejected: missing required fields`);
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

    console.log(
      `[${nowIso()}] [${requestId}] success messageId=${info.messageId} accepted=${JSON.stringify(
        info.accepted,
      )} rejected=${JSON.stringify(info.rejected)} elapsedMs=${Date.now() - startMs}`,
    );

    res.json({
      ok: true,
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected,
    });
  } catch (error) {
    console.error(`[${nowIso()}] [${requestId}] send failed`, {
      message: error?.message,
      code: error?.code,
      command: error?.command,
      response: error?.response,
      responseCode: error?.responseCode,
      stack: error?.stack,
      elapsedMs: Date.now() - startMs,
      smtpHost: SMTP_HOST,
      smtpPort: SMTP_PORT,
      smtpSecure: true,
    });
    res.status(500).json({
      ok: false,
      error: error?.message || 'SMTP send failed',
    });
  }
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(
    `[${nowIso()}] PDG email backend listening on http://localhost:${PORT} | smtpHost=${SMTP_HOST} smtpPort=${SMTP_PORT} secure=true user=${SMTP_USER}`,
  );
});
