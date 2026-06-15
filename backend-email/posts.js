'use strict';

// ---------------------------------------------------------------------------
// Cache server-side dei post + categorie del plugin WordPress "pdg-app".
//
// Replica lato backend la logica che l'app Flutter eseguiva sul dispositivo:
//   - download post dal plugin API (pdg-app/v1/posts)
//   - download categorie (pdg-app/v1/categories)
//   - arricchimento di ogni post con _embedded.wp:term (mapping ID -> categoria)
//     -> stesso comportamento di _enrichPostsWithCategories in main.dart
//   - cache con timestamp (come cached_posts / cache_timestamp)
//
// In piu' aggiunge una cache condivisa con strategia stale-while-revalidate:
// la prima richiesta "scalda" la cache, le successive rispondono all'istante
// e l'aggiornamento dal WordPress avviene in background.
// ---------------------------------------------------------------------------

const crypto = require('crypto');
const express = require('express');

// ⚡ Connessioni keep-alive verso WordPress: sotto carico (molti utenti) il
// riuso del canale TLS riduce sensibilmente la latenza per richiesta. Il
// fetch globale di Node usa già undici con keep-alive; qui lo regoliamo con
// un pool più ampio. Avvolto in try/catch perché 'undici' non è sempre
// importabile come modulo: in quel caso restano i default (comunque keep-alive).
try {
  // eslint-disable-next-line global-require
  const { setGlobalDispatcher, Agent } = require('undici');
  if (typeof setGlobalDispatcher === 'function' && typeof Agent === 'function') {
    setGlobalDispatcher(
      new Agent({
        keepAliveTimeout: 30_000,
        keepAliveMaxTimeout: 60_000,
        connections: 64, // pool di connessioni riusabili verso WordPress
      }),
    );
  }
} catch (_) {
  // undici non disponibile come require: i default di Node vanno comunque bene.
}

const WP_API_BASE =
  process.env.WP_API_BASE ||
  'https://www.portobellodigallura.it/wp-json/pdg-app/v1';

// API key del plugin: usata come fallback se il client non inoltra l'header.
// Allineata a ApiService.apiKey nell'app Flutter.
const WP_API_KEY =
  process.env.WP_API_KEY || 'Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe';

// TTL "fresco": entro questa finestra la cache viene servita senza refresh.
const POSTS_TTL_MS = Number(process.env.POSTS_TTL_MS) || 120_000; // 2 min
const CATEGORIES_TTL_MS =
  Number(process.env.CATEGORIES_TTL_MS) || 1_800_000; // 30 min

// Finestra "stale": oltre il TTL ma entro questo limite la cache viene comunque
// servita subito mentre parte un refresh in background. Oltre questo limite la
// voce e' considerata troppo vecchia e si attende il refresh sincrono.
const POSTS_STALE_MS = Number(process.env.POSTS_STALE_MS) || 900_000; // 15 min

// Timeout verso WordPress (hosting lento): generoso ma non infinito.
const WP_TIMEOUT_MS = Number(process.env.WP_TIMEOUT_MS) || 25_000;

const postsStore = new Map(); // key -> { data, fetchedAt }
const categoriesStore = new Map(); // key -> { data, fetchedAt }
const inflightPosts = new Map(); // key -> Promise
const inflightCategories = new Map(); // key -> Promise

function nowIso() {
  return new Date().toISOString();
}

/** Header di autenticazione da inoltrare a WordPress, derivati dalla richiesta. */
function buildWpHeaders(req) {
  const apiKey = req.get('x-pdg-api-key') || WP_API_KEY;
  const auth = req.get('authorization') || '';
  const token = req.get('x-pdg-token') || '';
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    'x-pdg-api-key': apiKey,
  };
  if (auth) headers.Authorization = auth;
  if (token) headers['x-pdg-token'] = token;
  return headers;
}

/**
 * Identita' utente usata come chiave di cache: i post privati dipendono dal
 * token/ruoli dell'utente, quindi la cache e' segmentata per token.
 */
function identityKey(req) {
  const token = req.get('x-pdg-token') || '';
  const auth = req.get('authorization') || '';
  const raw = token || auth || 'public';
  return crypto.createHash('sha1').update(raw).digest('hex').slice(0, 16);
}

function postsCacheKey(req, query) {
  const id = identityKey(req);
  const qs = [
    `page=${query.page}`,
    `per_page=${query.per_page}`,
    `orderby=${query.orderby}`,
    `order=${query.order}`,
    `category=${query.category ?? ''}`,
  ].join('&');
  return `${id}|${qs}`;
}

function normalizeQuery(rawQuery) {
  return {
    page: String(rawQuery.page || '1'),
    per_page: String(rawQuery.per_page || '100'),
    orderby: String(rawQuery.orderby || 'date'),
    order: String(rawQuery.order || 'DESC'),
    category:
      rawQuery.category != null && `${rawQuery.category}`.length
        ? String(rawQuery.category)
        : null,
  };
}

async function wpGet(path, query, headers) {
  const url = new URL(`${WP_API_BASE}${path}`);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v != null && `${v}`.length) url.searchParams.set(k, `${v}`);
    }
  }
  const response = await fetch(url.toString(), {
    method: 'GET',
    headers,
    signal: AbortSignal.timeout(WP_TIMEOUT_MS),
  });
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch (_) {
    body = null;
  }
  if (!response.ok) {
    const message =
      (body && (body.message || body.error)) ||
      `WordPress API error ${response.status}`;
    const err = new Error(message);
    err.status = response.status;
    throw err;
  }
  return body;
}

// --- Categorie -------------------------------------------------------------

async function fetchCategoriesFresh(req) {
  const headers = buildWpHeaders(req);
  const body = await wpGet('/categories', null, headers);
  const list = Array.isArray(body) ? body : Array.isArray(body?.categories) ? body.categories : [];
  return list;
}

async function getCategories(req) {
  const key = identityKey(req);
  const entry = categoriesStore.get(key);
  const now = Date.now();
  if (entry && now - entry.fetchedAt < CATEGORIES_TTL_MS) {
    return entry.data;
  }
  if (inflightCategories.has(key)) {
    return inflightCategories.get(key);
  }
  const promise = (async () => {
    try {
      const list = await fetchCategoriesFresh(req);
      categoriesStore.set(key, { data: list, fetchedAt: Date.now() });
      return list;
    } catch (e) {
      // In caso di errore mantieni l'eventuale cache vecchia.
      if (entry) return entry.data;
      throw e;
    } finally {
      inflightCategories.delete(key);
    }
  })();
  inflightCategories.set(key, promise);
  return promise;
}

// --- Arricchimento post con categorie (porting di _enrichPostsWithCategories)

function enrichPostsWithCategories(posts, categories) {
  if (!Array.isArray(posts) || posts.length === 0) return posts || [];
  const categoryMap = new Map();
  for (const cat of categories || []) {
    if (cat && cat.id != null) categoryMap.set(Number(cat.id), cat);
  }

  return posts.map((post) => {
    if (!post || typeof post !== 'object') return post;
    const hasEmbeddedTerms =
      post._embedded && post._embedded['wp:term'] != null;
    if (hasEmbeddedTerms) return post;

    const postCategories = Array.isArray(post.categories)
      ? post.categories
      : [];
    if (postCategories.length === 0) return post;

    const mapped = postCategories
      .filter((id) => Number.isInteger(id) || /^\d+$/.test(`${id}`))
      .map((id) => {
        const catId = Number(id);
        return (
          categoryMap.get(catId) || {
            id: catId,
            name: `Categoria ${catId}`,
            slug: `categoria-${catId}`,
          }
        );
      });

    if (mapped.length === 0) return post;

    return {
      ...post,
      _embedded: {
        ...(post._embedded || {}),
        'wp:term': [mapped],
      },
    };
  });
}

function postsAlreadyHaveCategoryNames(posts) {
  if (!Array.isArray(posts) || posts.length === 0) return false;
  return posts.every((post) => {
    const terms = post?._embedded?.['wp:term']?.[0];
    return (
      Array.isArray(terms) &&
      terms.length > 0 &&
      terms.every((term) => term && term.name)
    );
  });
}

// --- Post ------------------------------------------------------------------

async function fetchPostsFresh(req, query) {
  const headers = buildWpHeaders(req);
  const wpQuery = {
    page: query.page,
    per_page: query.per_page,
    orderby: query.orderby,
    order: query.order,
  };
  if (query.category) wpQuery.category = query.category;

  const body = await wpGet('/posts', wpQuery, headers);

  const rawPosts = Array.isArray(body)
    ? body
    : Array.isArray(body?.posts)
      ? body.posts
      : [];
  const categories = postsAlreadyHaveCategoryNames(rawPosts)
    ? []
    : await getCategories(req).catch(() => []);
  const enriched = categories.length
    ? enrichPostsWithCategories(rawPosts, categories)
    : rawPosts;

  return {
    posts: enriched,
    current_page: body?.current_page ?? Number(query.page) ?? 1,
    total: body?.total ?? enriched.length,
    total_pages: body?.total_pages ?? null,
    has_more: body?.has_more ?? null,
    note: body?.note ?? null,
  };
}

function storePostsFresh(key, req, query) {
  if (inflightPosts.has(key)) return inflightPosts.get(key);
  const promise = (async () => {
    try {
      const data = await fetchPostsFresh(req, query);
      postsStore.set(key, { data, fetchedAt: Date.now() });
      return data;
    } finally {
      inflightPosts.delete(key);
    }
  })();
  inflightPosts.set(key, promise);
  return promise;
}

async function getPosts(req, query) {
  const key = postsCacheKey(req, query);
  const entry = postsStore.get(key);
  const now = Date.now();

  // 1) Cache fresca -> risposta immediata.
  if (entry && now - entry.fetchedAt < POSTS_TTL_MS) {
    return {
      data: entry.data,
      cache: { hit: true, stale: false, ageMs: now - entry.fetchedAt },
    };
  }

  // 2) Cache stantia ma utilizzabile -> servi subito e aggiorna in background.
  if (entry && now - entry.fetchedAt < POSTS_STALE_MS) {
    storePostsFresh(key, req, query).catch((e) => {
      console.error(
        `[${nowIso()}] [posts] background refresh failed key=${key}: ${e?.message}`,
      );
    });
    return {
      data: entry.data,
      cache: { hit: true, stale: true, ageMs: now - entry.fetchedAt },
    };
  }

  // 3) Nessuna cache (o troppo vecchia) -> fetch sincrono.
  try {
    const data = await storePostsFresh(key, req, query);
    return { data, cache: { hit: false, stale: false, ageMs: 0 } };
  } catch (e) {
    // Se WordPress fallisce ma esiste una cache vecchissima, meglio servirla.
    if (entry) {
      return {
        data: entry.data,
        cache: { hit: true, stale: true, ageMs: now - entry.fetchedAt },
      };
    }
    throw e;
  }
}

function createPostsRouter() {
  const router = express.Router();

  router.get('/posts', async (req, res) => {
    const startMs = Date.now();
    const query = normalizeQuery(req.query);
    try {
      const { data, cache } = await getPosts(req, query);
      console.log(
        `[${nowIso()}] [posts] served count=${data.posts.length} cache=${cache.hit ? (cache.stale ? 'stale' : 'fresh') : 'miss'} ageMs=${cache.ageMs} elapsedMs=${Date.now() - startMs}`,
      );
      res.set('Cache-Control', 'no-store');
      return res.json({
        ok: true,
        posts: data.posts,
        current_page: data.current_page,
        total: data.total,
        total_pages: data.total_pages,
        has_more: data.has_more,
        note: data.note,
        cache,
      });
    } catch (e) {
      console.error(
        `[${nowIso()}] [posts] failed: ${e?.message} status=${e?.status || ''} elapsedMs=${Date.now() - startMs}`,
      );
      return res.status(e?.status >= 400 ? e.status : 502).json({
        ok: false,
        error: e?.message || 'Errore download post',
        posts: [],
      });
    }
  });

  router.get('/categories', async (req, res) => {
    const startMs = Date.now();
    try {
      const categories = await getCategories(req);
      console.log(
        `[${nowIso()}] [categories] served count=${categories.length} elapsedMs=${Date.now() - startMs}`,
      );
      res.set('Cache-Control', 'no-store');
      // Stesso shape del plugin: array puro (compatibile con ApiService.fetchCategories).
      return res.json(categories);
    } catch (e) {
      console.error(
        `[${nowIso()}] [categories] failed: ${e?.message} elapsedMs=${Date.now() - startMs}`,
      );
      return res.status(e?.status >= 400 ? e.status : 502).json({
        ok: false,
        error: e?.message || 'Errore download categorie',
      });
    }
  });

  // Pulizia cache manuale (utile dopo pubblicazione di nuovi post).
  router.post('/cache/clear', (req, res) => {
    const secret = process.env.CACHE_CLEAR_SECRET;
    if (secret && req.get('x-cache-secret') !== secret) {
      return res.status(403).json({ ok: false, error: 'Forbidden' });
    }
    const cleared = postsStore.size + categoriesStore.size;
    postsStore.clear();
    categoriesStore.clear();
    console.log(`[${nowIso()}] [cache] cleared entries=${cleared}`);
    return res.json({ ok: true, cleared });
  });

  return router;
}

module.exports = { createPostsRouter, enrichPostsWithCategories };
