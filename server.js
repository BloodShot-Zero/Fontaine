const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const port = Number(process.env.PORT) || 8765;
const mirrorCache = new Map();
const cacheDuration = 5 * 60 * 1000;
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml'
};

function extractJSON(script) {
  const assignment = script.match(/\bvar\s+jsondata\s*=/);
  if (!assignment) throw new Error('Embed page did not contain mirror metadata.');
  const start = assignment.index + assignment[0].length;
  const objectStart = script.indexOf('{', start);
  if (objectStart < 0) throw new Error('Mirror metadata was malformed.');

  let depth = 0, quote = '', escaped = false;
  for (let i = objectStart; i < script.length; i++) {
    const char = script[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '"' || char === "'") { quote = char; continue; }
    if (char === '{') depth++;
    else if (char === '}' && --depth === 0) return JSON.parse(script.slice(objectStart, i + 1));
  }
  throw new Error('Mirror metadata was incomplete.');
}

async function checkUniversalMirror(videoName) {
  const checks = await Promise.all(['w1', 'w2'].map(async host => {
    const url = `https://${host}.hentaiocean.com/video/h264/${encodeURIComponent(videoName)}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try { return { host, available: (await fetch(url, { method: 'HEAD', signal: controller.signal })).ok }; }
    catch (error) { return { host, available: false }; }
    finally { clearTimeout(timer); }
  }));
  return checks.find(check => check.available)?.host || '';
}

async function loadMirrors(slug) {
  const cached = mirrorCache.get(slug);
  if (cached && Date.now() - cached.at < cacheDuration) return cached.servers;

  const response = await fetch(`https://hentaiocean.com/embed/${encodeURIComponent(slug)}`);
  if (!response.ok) throw new Error(`Hentai player answered ${response.status}.`);
  const html = await response.text();
  const script = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(match => match[1]).find(text => /\bvar\s+jsondata\s*=/.test(text));
  if (!script) throw new Error('Hentai player did not provide mirror metadata.');

  const data = extractJSON(script);
  const vip = (Array.isArray(data.mirrors) ? data.mirrors : []).find(mirror => {
    try {
      const url = new URL(mirror.mirrorurl);
      return url.protocol === 'https:' &&
        ['w1.hentaiocean.com', 'w2.hentaiocean.com'].includes(url.hostname) &&
        url.pathname === '/play' && url.searchParams.has('vid');
    } catch (error) { return false; }
  });
  if (!vip) throw new Error('No VIP mirror is available for this episode.');

  const vipURL = new URL(vip.mirrorurl);
  vipURL.searchParams.set('pt', '0');
  const videoName = vipURL.searchParams.get('vid');
  const servers = [{ value: 'furina', label: 'VIP Mirror 1 · Furina', url: vipURL.href }];
  const universalHost = await checkUniversalMirror(videoName);
  if (universalHost) {
    const universalURL = new URL(`https://${universalHost}.hentaiocean.com/universal`);
    universalURL.searchParams.set('vid', videoName);
    universalURL.searchParams.set('pt', '0');
    servers.push({ value: 'phrolova', label: 'Universal Mirror · Phrolova', url: universalURL.href });
  }
  mirrorCache.set(slug, { at: Date.now(), servers });
  return servers;
}

async function searchGifs(query) {
  const apiKey = process.env.TENOR_API_KEY;
  if (!apiKey) {
    const error = new Error('TENOR_API_KEY is not configured on the Fontaine server.');
    error.statusCode = 503;
    throw error;
  }
  const url = new URL('https://tenor.googleapis.com/v2/search');
  url.search = new URLSearchParams({
    key: apiKey,
    client_key: process.env.TENOR_CLIENT_KEY || 'fontaine_pc',
    q: query,
    limit: '15',
    contentfilter: 'medium',
    media_filter: 'gif,tinygif,mediumgif',
    country: 'US',
    locale: 'en_US'
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) {
      const error = new Error(`Tenor search answered ${response.status}.`);
      error.statusCode = 502;
      throw error;
    }
    const payload = await response.json();
    const gifs = (Array.isArray(payload.results) ? payload.results : []).flatMap(item => {
      const formats = item && item.media_formats || {};
      const media = formats.gif || formats.mediumgif || formats.tinygif;
      const preview = formats.tinygif || formats.mediumgif || media;
      const gifURL = media && media.url, previewURL = preview && preview.url;
      const allowedURL = value => {
        try {
          const parsed = new URL(value);
          return parsed.protocol === 'https:' && /^(?:media\.tenor\.com|c\.tenor\.com)$/.test(parsed.hostname);
        } catch (error) { return false; }
      };
      return allowedURL(gifURL) && allowedURL(previewURL)
        ? [{ id: String(item.id || ''), title: String(item.content_description || 'Tenor'), url: gifURL, preview: previewURL }]
        : [];
    });
    return gifs;
  } finally { clearTimeout(timer); }
}

async function handleRequest(req, res) {
  const requestURL = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const mirrorMatch = requestURL.pathname.match(/^\/api\/hentai-mirrors\/([A-Za-z0-9_-]{1,160})$/);
  if (mirrorMatch) {
    if (req.method !== 'GET') { res.writeHead(405, { Allow: 'GET' }).end(); return; }
    try {
      const servers = await loadMirrors(mirrorMatch[1]);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ servers }));
    } catch (error) {
      res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ error: error.message || 'Could not load mirror options.' }));
    }
    return;
  }
  if (requestURL.pathname === '/api/tenor/search') {
    if (req.method !== 'GET') { res.writeHead(405, { Allow: 'GET' }).end(); return; }
    const query = (requestURL.searchParams.get('q') || '').trim();
    if (query.length < 1 || query.length > 80) {
      res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ error: 'Search text must be between 1 and 80 characters.' }));
      return;
    }
    try {
      const gifs = await searchGifs(query);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ gifs }));
    } catch (error) {
      const status = error.statusCode || (error.name === 'AbortError' ? 504 : 502);
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ error: error.name === 'AbortError' ? 'Tenor search timed out.' : error.message || 'Could not search Tenor.' }));
    }
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405, { Allow: 'GET, HEAD' }).end(); return; }

  const pathname = decodeURIComponent(requestURL.pathname);
  const file = path.resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (error, contents) => {
    if (error) { res.writeHead(404).end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': contentTypes[path.extname(file).toLowerCase()] || 'application/octet-stream' });
    res.end(req.method === 'HEAD' ? undefined : contents);
  });
}

http.createServer((req, res) => {
  handleRequest(req, res).catch(error => {
    console.error('Request failed:', error);
    if (!res.headersSent) res.writeHead(500);
    res.end('Internal server error');
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Fontaine available at http://127.0.0.1:${port}/`);
});
