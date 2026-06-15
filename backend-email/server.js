const express = require('express');
const cors = require('cors');
const compression = require('compression');
const { createPostsRouter } = require('./posts');

const PORT = Number(process.env.PORT) || 8080;

const TURBO_API_URL = 'https://api.turbo-smtp.com/api/v2/mail/send';
const CONSUMER_KEY = 'eb76d2df1111fe69401d';
const CONSUMER_SECRET = 'hCaVAzwHPRJXlkMcU2fd';
const SMTP_FROM =
  process.env.SMTP_FROM || 'no-reply@portobellodigallura.email';
/** Nome visualizzato del mittente (TurboSMTP: from_name). */
const SMTP_FROM_NAME =
  process.env.SMTP_FROM_NAME || 'NO-REPLY | Portobellodigallura.it';

const app = express();
let requestCounter = 0;

// ⚡ Compressione gzip/deflate: riduce ~70-80% il payload JSON dei post.
// Il pacchetto http di Flutter decomprime automaticamente, nessuna modifica
// lato app necessaria.
app.use(compression({ threshold: 1024 }));
app.use(cors());
app.use(express.json({ limit: '1mb' }));

function nowIso() {
  return new Date().toISOString();
}

function toTitleCase(value) {
  return value
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function splitNameAndSurname(fullName) {
  const normalized = (fullName || '').trim().replace(/\s+/g, ' ');
  if (!normalized) return { name: '', surname: '', fullName: '' };

  const parts = normalized.split(' ');
  const name = toTitleCase(parts[0] || '');
  const surname = toTitleCase(parts.slice(1).join(' '));
  return {
    name,
    surname,
    fullName: [name, surname].filter(Boolean).join(' '),
  };
}

function parseNameFromEmail(email) {
  const atIndex = (email || '').indexOf('@');
  if (atIndex <= 0) return { name: '', surname: '', fullName: '' };

  const localPart = email.slice(0, atIndex).replace(/[._-]+/g, ' ').trim();
  return splitNameAndSurname(localPart);
}

function getTextLineValue(text, label) {
  if (!text) return '';
  const match = text.match(new RegExp(`^${label}:\\s*(.+)$`, 'im'));
  return match?.[1]?.trim() || '';
}

function resolveRequesterIdentity({
  requestName,
  requestSurname,
  requestFullName,
  text,
  replyTo,
}) {
  const explicitName = (requestName || '').trim();
  const explicitSurname = (requestSurname || '').trim();
  const explicitFullName = (requestFullName || '').trim();
  const fromFullName = splitNameAndSurname(explicitFullName);
  const fromExplicitFields = splitNameAndSurname(
    [explicitName, explicitSurname].filter(Boolean).join(' '),
  );
  const fromTextLine = splitNameAndSurname(getTextLineValue(text, 'Nome'));
  const fromEmail = parseNameFromEmail(replyTo);

  // Priorita: campi espliciti, poi parsing dal testo, poi parsing dall'email.
  // Se una fonte contiene solo il nome, completiamo il cognome con la fonte successiva.
  const resolvedName =
    fromFullName.name ||
    fromExplicitFields.name ||
    fromTextLine.name ||
    fromEmail.name ||
    explicitName;
  const resolvedSurname =
    fromFullName.surname ||
    fromExplicitFields.surname ||
    fromTextLine.surname ||
    fromEmail.surname ||
    explicitSurname;

  return {
    name: resolvedName || 'Non disponibile',
    surname: resolvedSurname || 'Non disponibile',
  };
}

function isWastePickupRequest(subject, text, html) {
  const normalized = [subject, text, html]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  return normalized.includes('ritiro rifiuti');
}

function appendIdentityToText(text, identity) {
  const base = (text || '').trimEnd();
  const identityBlock = [
    '',
    '---',
    'Dati richiedente (backend):',
    `Nome: ${identity.name}`,
    `Cognome: ${identity.surname}`,
  ].join('\n');
  return `${base}${identityBlock}`;
}

function appendIdentityToHtml(html, identity) {
  const base = (html || '').trimEnd();
  const identityBlock =
    '<hr><p><strong>Dati richiedente (backend):</strong><br>' +
    `Nome: ${identity.name}<br>` +
    `Cognome: ${identity.surname}</p>`;
  return `${base}${identityBlock}`;
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

// Cache + proxy dei post/categorie del plugin WordPress (download veloce app).
app.use('/', createPostsRouter());

app.post('/send-email', async (req, res) => {
  const requestId = `mail-${Date.now()}-${++requestCounter}`;
  const startMs = Date.now();
  const {
    to,
    subject,
    text: incomingText,
    html: incomingHtml,
    replyTo,
    name,
    surname,
    fullName,
  } = req.body || {};
  let text = incomingText;
  let html = incomingHtml;

  console.log(
    `[${nowIso()}] [${requestId}] payload to=${to || 'missing'} subject="${subject || 'missing'}" text=${Boolean(text)} html=${Boolean(html)} replyTo=${Boolean(replyTo)} from="${SMTP_FROM_NAME}" <${SMTP_FROM}>`,
  );

  if (!to || !subject || (!text && !html)) {
    console.warn(`[${nowIso()}] [${requestId}] rejected: missing required fields`);
    return res.status(400).json({
      ok: false,
      error: 'Missing required fields: to, subject, text/html',
    });
  }

  if (isWastePickupRequest(subject, text, html)) {
    const identity = resolveRequesterIdentity({
      requestName: name,
      requestSurname: surname,
      requestFullName: fullName,
      text,
      replyTo,
    });
    text = appendIdentityToText(text, identity);
    html = appendIdentityToHtml(html, identity);
    console.log(
      `[${nowIso()}] [${requestId}] waste-pickup identity attached name="${identity.name}" surname="${identity.surname}"`,
    );
  }

  /** Mittente: nome visualizzato + indirizzo (TurboSMTP: from + from_name). */
  const payload = {
    from: SMTP_FROM,
    from_name: SMTP_FROM_NAME,
    to,
    subject,
    ...(text && { content: text }),
    ...(html && { html_content: html }),
    ...(replyTo && { reply_to: replyTo }),
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
    `[${nowIso()}] PDG email backend listening on http://localhost:${PORT} | via TurboSMTP HTTP API | from="${SMTP_FROM_NAME}" <${SMTP_FROM}>`,
  );
});
