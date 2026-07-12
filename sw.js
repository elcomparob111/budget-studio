const CACHE = "budget-studio-v33";
const ASSETS = [
  "./",
  "./index.html",
  "./app.js",
  "./sync.js",
  "./sync-config.js",
  "./security.js",
  "./styles.css",
  "./manifest.json",
  "./privacy.html",
  "./terms.html",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
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
  // Never cache authenticated API / cross-origin responses (Supabase, CDNs with tokens, etc.).
  try {
    const reqUrl = new URL(request.url);
    if (reqUrl.origin !== self.location.origin) return false;
  } catch {
    return false;
  }
  const ct = response.headers.get("content-type") || "";
  // Only cache static app assets, not JSON API bodies that might contain user data.
  if (ct.includes("application/json")) return false;
  return request.method === "GET";
}

// Network-first so style/script changes show up on the next reload;
// the cache is only a fallback for offline use of same-origin static assets.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;

  // Bypass SW for cross-origin (Supabase Auth/REST) — never intercept user data APIs.
  try {
    const reqUrl = new URL(event.request.url);
    if (reqUrl.origin !== self.location.origin) return;
  } catch {
    return;
  }

  event.respondWith(
    fetch(event.request)
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
