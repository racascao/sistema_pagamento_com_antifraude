package batch_test

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/racascao/payment-processor-course/pkg/batch"
)

func TestSubmitAfterClose(t *testing.T) {
	echo := func(_ context.Context, items []int) ([]int, error) {
		return items, nil
	}
	b := batch.New(2, time.Millisecond*100, echo)
	b.Close()
	_, err := b.Submit(context.Background(), 1)
	if !errors.Is(err, batch.ErrClosed) {
		t.Fatalf("expected ErrClosed, got %v", err)
	}
}

func TestNewNormalizesMaxSize(t *testing.T) {
	echo := func(_ context.Context, items []int) ([]int, error) {
		return items, nil
	}

	batcher := batch.New(0, time.Second, echo)
	defer batcher.Close()

	result, err := batcher.Submit(context.Background(), 3)
	if err != nil {
		t.Fatalf("Submit() error = %v", err)
	}
	if result != 3 {
		t.Fatalf("Submit() = %d, want 3", result)
	}
}

func TestSubmitWithCanceledContext(t *testing.T) {
	echo := func(_ context.Context, items []int) ([]int, error) {
		return items, nil
	}

	batcher := batch.New(1, time.Second, echo)
	defer batcher.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := batcher.Submit(ctx, 1)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("Submit() error = %v, want context canceled", err)
	}
}

func TestBatchesBySize(t *testing.T) {
	var calls atomic.Int32
	double := func(_ context.Context, items []int) ([]int, error) {
		calls.Add(1)
		results := make([]int, len(items))
		for i, item := range items {
			results[i] = item * 2
		}
		return results, nil
	}

	batcher := batch.New(4, time.Second, double)
	defer batcher.Close()

	results := make([]int, 8)
	var wg sync.WaitGroup
	wg.Add(8)
	for i := range results {
		go func() {
			defer wg.Done()
			result, err := batcher.Submit(context.Background(), i)
			if err != nil {
				t.Errorf("Submit(%d) error = %v", i, err)
				return
			}
			results[i] = result
		}()
	}
	wg.Wait()

	for i, result := range results {
		if want := i * 2; result != want {
			t.Errorf("result[%d] = %d, want %d", i, result, want)
		}
	}
	if got := calls.Load(); got > 4 {
		t.Fatalf("flusher calls = %d, want at most 4", got)
	}
}

func TestFlushesByTimeWindow(t *testing.T) {
	echo := func(_ context.Context, items []string) ([]string, error) {
		return items, nil
	}

	batcher := batch.New(100, 20*time.Millisecond, echo)
	defer batcher.Close()

	startedAt := time.Now()
	result, err := batcher.Submit(context.Background(), "lonely")
	elapsed := time.Since(startedAt)

	if err != nil {
		t.Fatalf("Submit() error = %v", err)
	}
	if result != "lonely" {
		t.Fatalf("Submit() = %q, want %q", result, "lonely")
	}
	if elapsed > 500*time.Millisecond {
		t.Fatalf("Submit() waited %s, want at most 500ms", elapsed)
	}
}

func TestContextCancelUnblocksCaller(t *testing.T) {
	slow := func(_ context.Context, items []int) ([]int, error) {
		time.Sleep(200 * time.Millisecond)
		return items, nil
	}

	batcher := batch.New(10, 50*time.Millisecond, slow)
	defer batcher.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	_, err := batcher.Submit(ctx, 1)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("Submit() error = %v, want context deadline exceeded", err)
	}
}

func TestFlushError(t *testing.T) {
	flushErr := errors.New("flush failed")
	failing := func(_ context.Context, _ []int) ([]int, error) {
		return nil, flushErr
	}

	batcher := batch.New(1, time.Second, failing)
	defer batcher.Close()

	_, err := batcher.Submit(context.Background(), 1)
	if !errors.Is(err, flushErr) {
		t.Fatalf("Submit() error = %v, want %v", err, flushErr)
	}
}

func TestFlushWithWrongResultCount(t *testing.T) {
	short := func(_ context.Context, _ []int) ([]int, error) {
		return nil, nil
	}

	batcher := batch.New(1, time.Second, short)
	defer batcher.Close()

	_, err := batcher.Submit(context.Background(), 1)
	if err == nil {
		t.Fatal("Submit() error = nil, want flush result count error")
	}
}

func TestCloseIsIdempotent(t *testing.T) {
	echo := func(_ context.Context, items []int) ([]int, error) {
		return items, nil
	}

	batcher := batch.New(1, time.Second, echo)
	batcher.Close()
	batcher.Close()
}
