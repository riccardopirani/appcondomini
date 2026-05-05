const express = require('express');
const cors = require('cors');

const PORT = Number(process.env.PORT) || 8080;

const TURBO_API_URL = 'https://api.turbo-smtp.com/api/v2/mail/send';
const CONSUMER_KEY = 'eb76d2df1111fe69401d';
const CONSUMER_SECRET = 'hCaVAzwHPRJXlkMcU2fd';
const SMTP_FROM = 'no-reply@portobellodigallura.email';

const app = express();
let requestCounter = 0;

app.use(cors());
app.use(express.json({ limit: '1mb' }));

function nowIso() {
  return new Date().toISOString();
}

app.use((req, _res, next) => {
  console.log(
    `[${nowIso()}] [http] ${req.method} ${req.originalUrl} ip=${req.ip} ua="${req.get('user-agent') || 'n/a'}"`,
  );
  next();
});

app.get('/health', (_, res) => {
  res.json({ ok: true, service: 'pdg-email-backend' });
});

app.post('/send-email', async (req, res) => {
  const requestId = `mail-${Date.now()}-${++requestCounter}`;
  const startMs = Date.now();
  const { to, subject, text, html, replyTo, fromName } = req.body || {};

  console.log(
    `[${nowIso()}] [${requestId}] payload to=${to || 'missing'} subject="${subject || 'missing'}" text=${Boolean(text)} html=${Boolean(html)} replyTo=${Boolean(replyTo)} fromName="${fromName || 'pdg'}"`,
  );

  if (!to || !subject || (!text && !html)) {
    console.warn(`[${nowIso()}] [${requestId}] rejected: missing required fields`);
    return res.status(400).json({
      ok: false,
      error: 'Missing required fields: to, subject, text/html',
    });
  }

  const payload = {
    from: SMTP_FROM,
    to,
    subject,
    ...(text && { content: text }),
    ...(html && { html_content: html }),
    ...(replyTo && { reply_to: replyTo }),
    ...(fromName && { from_name: fromName }),
  };

  try {
    const response = await fetch(TURBO_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        consumerKey: CONSUMER_KEY,
        consumerSecret: CONSUMER_SECRET,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(30000),
    });

    const data = await response.json();

    console.log(
      `[${nowIso()}] [${requestId}] turbo-api response status=${response.status} body=${JSON.stringify(data)} elapsedMs=${Date.now() - startMs}`,
    );

    if (response.ok) {
      return res.json({
        ok: true,
        messageId: data.mid || data.message_id || null,
        accepted: [to],
        rejected: [],
      });
    }

    return res.status(response.status >= 400 ? response.status : 502).json({
      ok: false,
      error: data.message || data.error || `TurboSMTP API error ${response.status}`,
    });
  } catch (error) {
    console.error(`[${nowIso()}] [${requestId}] send failed`, {
      message: error?.message,
      code: error?.code,
      type: error?.type,
      elapsedMs: Date.now() - startMs,
    });
    res.status(500).json({
      ok: false,
      error: error?.message || 'Email send failed',
    });
  }
});

app.listen(PORT, () => {
  console.log(
    `[${nowIso()}] PDG email backend listening on http://localhost:${PORT} | via TurboSMTP HTTP API | from=${SMTP_FROM}`,
  );
});
