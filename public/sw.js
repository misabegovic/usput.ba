// Usput Service Worker - Offline Support
const CACHE_NAME = 'usput-v3';
const OFFLINE_URL = '/offline.html';

// Assets to cache immediately on install
const PRECACHE_ASSETS = [
  '/',
  '/offline.html',
  '/manifest.json',
  '/pwa-icon-192.png',
  '/pwa-icon-512.png'
];

// Helper to check if response is cacheable (not partial/206)
const isCacheable = (response) => {
  return response && response.ok && response.status !== 206;
};

// Cache strategies
const CACHE_STRATEGIES = {
  // Network first, fall back to cache (for HTML pages)
  networkFirst: async (request) => {
    try {
      const networkResponse = await fetch(request);
      if (isCacheable(networkResponse)) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    } catch (error) {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        return cachedResponse;
      }
      // Return offline page for navigation requests
      if (request.mode === 'navigate') {
        return caches.match(OFFLINE_URL);
      }
      throw error;
    }
  },

  // Cache first, fall back to network (for static assets)
  cacheFirst: async (request) => {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    try {
      const networkResponse = await fetch(request);
      if (isCacheable(networkResponse)) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    } catch (error) {
      throw error;
    }
  },

  // Stale while revalidate (for API responses)
  staleWhileRevalidate: async (request) => {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);

    const fetchPromise = fetch(request).then((networkResponse) => {
      if (isCacheable(networkResponse)) {
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    }).catch(() => cachedResponse);

    return cachedResponse || fetchPromise;
  },

  // Network only - don't cache (for media/streaming)
  networkOnly: async (request) => {
    return fetch(request);
  }
};

// Install event - precache essential assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Precaching assets');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('[SW] Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - handle requests with appropriate strategy
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    return;
  }

  // Skip admin routes
  if (url.pathname.startsWith('/admin')) {
    return;
  }

  // Choose strategy based on request type
  let strategy;

  // Media files (audio/video) - network only, don't cache (supports range requests)
  if (
    url.pathname.match(/\.(mp3|mp4|ogg|wav|webm|m4a|aac|flac)$/) ||
    url.pathname.includes('/rails/active_storage/') ||
    request.headers.get('range')
  ) {
    strategy = CACHE_STRATEGIES.networkOnly;
  }
  // HTML pages - network first
  else if (request.mode === 'navigate' || request.headers.get('accept')?.includes('text/html')) {
    strategy = CACHE_STRATEGIES.networkFirst;
  }
  // Static assets - cache first
  else if (
    url.pathname.startsWith('/assets/') ||
    url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2)$/)
  ) {
    strategy = CACHE_STRATEGIES.cacheFirst;
  }
  // API/JSON requests - stale while revalidate
  else if (url.pathname.endsWith('.json') || request.headers.get('accept')?.includes('application/json')) {
    strategy = CACHE_STRATEGIES.staleWhileRevalidate;
  }
  // Default - network first
  else {
    strategy = CACHE_STRATEGIES.networkFirst;
  }

  event.respondWith(strategy(request));
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-travel-profile') {
    event.waitUntil(syncTravelProfile());
  }
});

// Push notifications (future feature)
self.addEventListener('push', (event) => {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.body,
    icon: '/pwa-icon-192.png',
    badge: '/pwa-icon-192.png',
    vibrate: [100, 50, 100],
    data: {
      url: data.url || '/'
    }
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'Usput', options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window' })
      .then((clientList) => {
        // Focus existing window or open new one
        for (const client of clientList) {
          if (client.url === event.notification.data.url && 'focus' in client) {
            return client.focus();
          }
        }
        return clients.openWindow(event.notification.data.url);
      })
  );
});

// Helper function to sync travel profile (placeholder)
async function syncTravelProfile() {
  // This would sync localStorage data with a backend if we had one
  console.log('[SW] Syncing travel profile...');
}
