const express = require('express');

const app = express();
const port = process.env.PORT || 8787;
const upstreamBaseUrl =
  process.env.JIOSAAVN_UPSTREAM_BASE_URL || 'https://saavn.dev/api/search/songs';

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.sendStatus(204);
    return;
  }
  next();
});

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/api/search/songs', async (req, res) => {
  try {
    const query = `${req.query.query || ''}`.trim();
    const limit = `${req.query.limit || '40'}`.trim();

    if (!query) {
      res.status(400).json({ error: 'Missing query parameter.' });
      return;
    }

    const upstreamUrl = new URL(upstreamBaseUrl);
    upstreamUrl.searchParams.set('query', query);
    upstreamUrl.searchParams.set('limit', limit);

    const upstreamResponse = await fetch(upstreamUrl, {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'timp3player-proxy/1.0',
      },
    });

    const body = await upstreamResponse.text();
    res.status(upstreamResponse.status);
    res.type(upstreamResponse.headers.get('content-type') || 'application/json');
    res.send(body);
  } catch (error) {
    res.status(502).json({
      error: 'Proxy request failed.',
      details: error instanceof Error ? error.message : String(error),
    });
  }
});

app.listen(port, () => {
  console.log(`Online music proxy running on http://localhost:${port}`);
});
