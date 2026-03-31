# timp3player

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Online Music Proxy For Web

Flutter web cannot reliably call the unofficial JioSaavn-compatible API directly
because browser requests may be blocked by CORS. This repo includes a small
proxy in `proxy/server.js` for web usage.

### Run the proxy locally

```bash
cd proxy
npm install
npm start
```

The proxy listens on `http://localhost:8787` and exposes:

```text
GET /api/search/songs?query=<term>&limit=40
```

### Run Flutter web with the proxy

```bash
flutter run -d edge --dart-define=ONLINE_MUSIC_PROXY_BASE_URL=http://localhost:8787/api/search/songs
```

For deployed web builds, serve a proxy endpoint from the same origin and set:

```bash
flutter build web --dart-define=ONLINE_MUSIC_PROXY_BASE_URL=/api/search/songs
```
