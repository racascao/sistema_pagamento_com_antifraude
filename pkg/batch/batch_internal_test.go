package batch

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestSubmitStopsWhileQueueIsFull(t *testing.T) {
	batcher := &Batcher[int, int]{
		queue: make(chan request[int, int], 1),
	}
	batcher.queue <- request[int, int]{}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	_, err := batcher.Submit(ctx, 1)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("Submit() error = %v, want context deadline exceeded", err)
	}
}
