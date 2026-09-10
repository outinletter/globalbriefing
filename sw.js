const CACHE_NAME = 'global-briefing-v1';
const ASSETS = [
  './',
  './index.html',
  './dictionary.json',
  './globalbriefing.png'
];

// 설치 단계: 리소스 캐싱
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('Service Worker: Caching static assets');
      return cache.addAll(ASSETS);
    })
  );
  self.skipWaiting();
});

// 활성화 단계: 오래된 캐시 정리
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            console.log('Service Worker: Clearing old cache');
            return caches.delete(cache);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// 페치 단계: 네트워크 우선, 실패 시 캐시 반환 (단어장 등 정적 파일은 캐시 우선)
self.addEventListener('fetch', (event) => {
  // API 요청은 캐싱하지 않음
  if (event.request.url.includes('api.deepseek.com')) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request).then((fetchResponse) => {
        // 동적 리소스(예: 외부 이미지 등)를 캐싱하고 싶다면 여기서 추가 가능
        return fetchResponse;
      });
    }).catch(() => {
        // 오프라인 상태에서 요청 실패 시 기본 페이지 반환
        if (event.request.mode === 'navigate') {
            return caches.match('./index.html');
        }
    })
  );
});
