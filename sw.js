// Offline support: the app shell is served from cache instantly and refreshed in the background;
// the timetable file is fetched fresh when online and falls back to the cached copy offline.
// Bump this whenever index.html changes so phones fetch the new app on their next visit.
const VERSION = "st-v3";
const SHELL = ["./", "index.html", "manifest.webmanifest", "icons/icon-192.png", "icons/icon-512.png", "data/timetables.json"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;

  if (url.pathname.endsWith("/data/timetables.json")) {
    e.respondWith(
      fetch(e.request).then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put("data/timetables.json", copy)); }
        return res;
      }).catch(() => caches.match("data/timetables.json"))
    );
    return;
  }

  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(hit => {
      const net = fetch(e.request).then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put(e.request, copy)); }
        return res;
      }).catch(() => hit || caches.match("index.html"));
      return hit || net;
    })
  );
});
