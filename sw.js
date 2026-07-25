const CACHE = "budget-studio-v100";
const ASSETS = [
  "./",
  "./index.html",
  "./boot.js?v=99",
  "./app.js?v=99",
  "./sync.js?v=99",
  "./sync-config.js?v=99",
  "./security.js?v=99",
  "./tokens.css?v=99",
  "./styles.css?v=99",
  "./legal.css?v=100",
  "./manifest.json",
  "./privacy.html",
  "./terms.html",
  "./icons/icon-192.png?v=99",
  "./icons/icon-512.png?v=99",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))),
  );
  self.clients.claim();
});

function shouldCacheResponse(request, response) {
  if (!response || !response.ok) return false;
  try {
    const reqUrl = new URL(request.url);
    if (reqUrl.origin !== self.location.origin) return false;
  } catch {
    return false;
  }
  const ct = response.headers.get("content-type") || "";
  if (ct.includes("application/json")) return false;
  return request.method === "GET";
}

// Always revalidate so HTML and JS stay on the same build (stale app.js broke Goals + Activity chart).
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;

  try {
    const reqUrl = new URL(event.request.url);
    if (reqUrl.origin !== self.location.origin) return;
  } catch {
    return;
  }

  event.respondWith(
    fetch(event.request, { cache: "no-cache" })
      .then((response) => {
        if (shouldCacheResponse(event.request, response)) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }
        return response;
      })
      .catch(() => caches.match(event.request).then((cached) => cached || caches.match("./index.html"))),
  );
});
