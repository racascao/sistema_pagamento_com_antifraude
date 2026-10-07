package memcache

import (
	"hash/fnv"
	"sync"
	"time"
)

const shardCount = 16

type entry[Value any] struct {
	value     Value
	expiresAt time.Time
}

type shard[Value any] struct {
	mu    sync.RWMutex
	items map[string]entry[Value]
}

type Cache[Value any] struct {
	shards [shardCount]*shard[Value]
	ttl    time.Duration
	now    func() time.Time
	stop   chan struct{}
	once   sync.Once
}

func New[Value any](ttl, sweepEvery time.Duration) *Cache[Value] {
	cache := &Cache[Value]{
		ttl:  ttl,
		now:  time.Now,
		stop: make(chan struct{}),
	}

	for i := range cache.shards {
		cache.shards[i] = &shard[Value]{
			items: make(map[string]entry[Value]),
		}
	}
	// TODO: inicializar os 16 shards no ponto em que essa etapa entrar.
	go cache.janitor(sweepEvery)

	return cache
}

func (cache *Cache[Value]) shardFor(key string) *shard[Value] {
	h := fnv.New32a()                         // cria o calculador de hash
	_, _ = h.Write([]byte(key))               // coloca a chave no cálculo
	return cache.shards[h.Sum32()%shardCount] // produz um uint32 determinístico
}

func (cache *Cache[Value]) SetTTL(key string, value Value, ttl time.Duration) {
	shard := cache.shardFor(key)
	shard.mu.Lock()
	defer shard.mu.Unlock()
	shard.items[key] = entry[Value]{
		value:     value,
		expiresAt: cache.now().Add(ttl),
	}
}
func (cache *Cache[Value]) Get(key string) (Value, bool) {
	shard := cache.shardFor(key)
	shard.mu.RLock()
	currentEntry, ok := shard.items[key]
	shard.mu.RUnlock()
	if !ok || cache.now().After(currentEntry.expiresAt) {
		var zero Value
		return zero, false
	}
	return currentEntry.value, true

}

func (cache *Cache[Value]) Set(key string, value Value) {
	cache.SetTTL(key, value, cache.ttl)
}

// Increment adds delta to an integer counter stored at key and returns
// the new total. Counters share the default TTL, refreshed on write.
// It is the primitive behind velocity checks.
func (cache *Cache[Value]) Increment(key string, counter func(current Value, exists bool) Value) Value {
	shard := cache.shardFor(key)
	shard.mu.Lock()
	defer shard.mu.Unlock()
	currentEntry, ok := shard.items[key]
	valid := ok && !cache.now().After(currentEntry.expiresAt)
	next := counter(currentEntry.value, valid)
	shard.items[key] = entry[Value]{
		value:     next,
		expiresAt: cache.now().Add(cache.ttl),
	}
	return next

}

// Len returns the number of itens in the cache
func (cache *Cache[Value]) Len() int {
	var total int
	for _, shard := range cache.shards {
		shard.mu.RLock()
		total += len(shard.items)
		shard.mu.RUnlock()
	}
	return total
}

func (cache *Cache[Value]) Close() error {
	cache.once.Do(func() {
		close(cache.stop)
	})
	return nil
}

func (cache *Cache[Value]) janitor(every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			now := cache.now()
			for _, shard := range cache.shards {
				shard.mu.Lock()
				for key, entry := range shard.items {
					if now.After(entry.expiresAt) {
						delete(shard.items, key)
					}
				}
				shard.mu.Unlock()
			}
		case <-cache.stop:
			return
		}
	}
}
