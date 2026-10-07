package memcache_test

import (
	"fmt"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/racascao/payment-processor-course/pkg/memcache"
)

func TestSetGet(t *testing.T) {
	cache := memcache.New[string](time.Minute, time.Minute)
	defer cache.Close()

	cache.Set("k", "v")
	got, ok := cache.Get("k")
	if !ok {
		t.Fatal("Get() ok = false, want true")
	}
	if got != "v" {
		t.Fatalf("Get() = %q, want %q", got, "v")
	}
}

func TestExpiration(t *testing.T) {
	cache := memcache.New[int](10*time.Millisecond, time.Hour)
	defer cache.Close()

	cache.Set("k", 42)
	time.Sleep(30 * time.Millisecond)

	if _, ok := cache.Get("k"); ok {
		t.Fatal("Get() ok = true after TTL, want false")
	}
}

func TestIncrementIsAtomic(t *testing.T) {
	cache := memcache.New[int](time.Minute, time.Minute)
	defer cache.Close()

	add := func(current int, exists bool) int {
		if exists {
			return current + 1
		}
		return 1
	}

	var wg sync.WaitGroup
	wg.Add(100)
	for range 100 {
		go func() {
			defer wg.Done()
			cache.Increment("card:123", add)
		}()
	}
	wg.Wait()

	got, ok := cache.Get("card:123")
	if !ok {
		t.Fatal("Get() ok = false, want true")
	}
	if got != 100 {
		t.Fatalf("Get() = %d, want 100", got)
	}
}

func TestConcurrentAccessAcrossShards(t *testing.T) {
	cache := memcache.New[int](time.Minute, time.Minute)
	defer cache.Close()

	var wg sync.WaitGroup
	wg.Add(200)
	for i := range 200 {
		go func() {
			defer wg.Done()
			key := fmt.Sprintf("key-%d", i%50)
			cache.Set(key, i)
			if _, ok := cache.Get(key); !ok {
				t.Errorf("Get(%q) ok = false after Set", key)
			}
		}()
	}
	wg.Wait()
}

func TestJanitorEvictsExpired(t *testing.T) {
	cache := memcache.New[int](time.Millisecond, time.Millisecond)
	defer cache.Close()

	for i := range 100 {
		cache.Set(fmt.Sprintf("expired-%d", i), i)
	}

	deadline := time.Now().Add(time.Second)
	for cache.Len() != 0 && time.Now().Before(deadline) {
		runtime.Gosched()
	}

	if got := cache.Len(); got != 0 {
		t.Fatalf("Len() = %d after janitor sweep, want 0", got)
	}
}
