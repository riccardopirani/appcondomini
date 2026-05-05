const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

/** Configurazione SMTP e server (ex .env.example) */
const PORT = Number(process.env.PORT) || 8080;
const SMTP_HOST = 'pro.eu.turbo-smtp.com';
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

const smtpRoutes = [
  { label: 'ssl-465', port: 465, secure: true },
  { label: 'starttls-587', port: 587, secure: false, requireTLS: true },
  { label: 'plain-2525', port: 2525, secure: false },
];

function createTransport(route) {
  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: route.port,
    secure: route.secure,
    requireTLS: route.requireTLS || false,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASSWORD,
    },
    logger: true,
    debug: true,
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 30000,
  });
}

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
  const mailOptions = {
    from: `"${fromName || 'pdg'}" <${fromAddress}>`,
    to,
    subject,
    text: text || undefined,
    html: html || undefined,
    replyTo: replyTo || undefined,
  };

  try {
    let info;
    let selectedRoute;
    let lastError;

    for (const route of smtpRoutes) {
      const transporter = createTransport(route);
      const routeStartMs = Date.now();
      console.log(
        `[${nowIso()}] [${requestId}] trying route=${route.label} host=${SMTP_HOST} port=${route.port} secure=${route.secure} requireTLS=${Boolean(route.requireTLS)}`,
      );

      try {
        info = await transporter.sendMail(mailOptions);
        selectedRoute = route;
        console.log(
          `[${nowIso()}] [${requestId}] route success=${route.label} elapsedMs=${Date.now() - routeStartMs}`,
        );
        break;
      } catch (routeError) {
        lastError = routeError;
        console.warn(`[${nowIso()}] [${requestId}] route failed=${route.label}`, {
          message: routeError?.message,
          code: routeError?.code,
          command: routeError?.command,
          responseCode: routeError?.responseCode,
          elapsedMs: Date.now() - routeStartMs,
        });
      }
    }

    if (!info || !selectedRoute) {
      throw lastError || new Error('SMTP send failed on all routes');
    }

    console.log(
      `[${nowIso()}] [${requestId}] success route=${selectedRoute.label} messageId=${info.messageId} accepted=${JSON.stringify(
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
      attemptedRoutes: smtpRoutes.map((route) => route.label),
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
    `[${nowIso()}] PDG email backend listening on http://localhost:${PORT} | smtpHost=${SMTP_HOST} routes=${smtpRoutes
      .map((route) => `${route.label}:${route.port}`)
      .join(',')} user=${SMTP_USER}`,
  );
});
