// Package batch implements a dynamic batcher. Callers submit items
// individually and the batcher groups them by size or time windows.
// whichever happens first. This trades a small bounded latency for
// a large gain in throughput on the downstream call.
package batch

import (
	"context"
	"errors"
	"sync"
	"time"
)

var ErrClosed = errors.New("batch: batcher is closed")

// Flusher processes a full batch. The implementation must be safe for
// concurrent calls because two windows can overlap under load.
type Flusher[In any, Out any] func(ctx context.Context, items []In) ([]Out, error)

type Batcher[In any, Out any] struct {
	maxSize int
	maxWait time.Duration
	flush   Flusher[In, Out]
	mu      sync.Mutex
	queue   chan request[In, Out]
	closed  bool
	wg      sync.WaitGroup
}

type request[In any, Out any] struct {
	item In
	resp chan result[Out]
}

type result[Out any] struct {
	value Out
	err   error
}

func New[In any, Out any](maxSize int, maxWait time.Duration, flush Flusher[In, Out]) *Batcher[In, Out] {
	if maxSize < 1 {
		maxSize = 1
	}

	batcher := &Batcher[In, Out]{
		maxSize: maxSize,
		maxWait: maxWait,
		flush:   flush,
		queue:   make(chan request[In, Out], maxSize*4),
	}
	batcher.wg.Add(1)
	go batcher.loop()

	return batcher
}

func (batcher *Batcher[In, Out]) Submit(ctx context.Context, item In) (Out, error) {
	var zero Out

	if err := ctx.Err(); err != nil {
		return zero, err
	}

	batcher.mu.Lock()
	if batcher.closed {
		batcher.mu.Unlock()
		return zero, ErrClosed
	}

	req := request[In, Out]{
		item: item,
		resp: make(chan result[Out], 1),
	}
	select {
	case batcher.queue <- req:
		batcher.mu.Unlock()
	case <-ctx.Done():
		batcher.mu.Unlock()
		return zero, ctx.Err()
	}

	select {
	case res := <-req.resp:
		return res.value, res.err
	case <-ctx.Done():
		return zero, ctx.Err()
	}
}

func (batcher *Batcher[In, Out]) Close() {
	batcher.mu.Lock()
	if batcher.closed {
		batcher.mu.Unlock()
		return
	}
	batcher.closed = true
	close(batcher.queue)
	batcher.mu.Unlock()

	batcher.wg.Wait()

}

func (batcher *Batcher[In, Out]) dispatch(batch []request[In, Out]) {

	items := make([]In, len(batch))
	for i, req := range batch {
		items[i] = req.item
	}

	results, err := batcher.flush(context.Background(), items)
	if err == nil && len(results) != len(batch) {
		err = errors.New("batch: flush returned wrong number of results")
	}

	for i, req := range batch {
		if err != nil {
			var zero Out
			req.resp <- result[Out]{err: err, value: zero}
			continue
		}
		req.resp <- result[Out]{value: results[i], err: nil}
	}
}

func (batcher *Batcher[In, Out]) loop() {
	defer batcher.wg.Done()
	pending := make([]request[In, Out], 0, batcher.maxSize)
	var timer *time.Timer
	var timerC <-chan time.Time

	flushPending := func() {
		if len(pending) == 0 {
			return
		}
		batch := pending
		pending = make([]request[In, Out], 0, batcher.maxSize)
		batcher.dispatch(batch)

	}
	stopTimer := func() {
		if timer == nil {
			return
		}
		timer.Stop()
		timer = nil
		timerC = nil
	}

	for {
		select {
		case req, ok := <-batcher.queue:
			if !ok {
				stopTimer()
				flushPending()
				return
			}
			pending = append(pending, req)
			if len(pending) == 1 {
				timer = time.NewTimer(batcher.maxWait)
				timerC = timer.C
			}
			if len(pending) >= batcher.maxSize {
				stopTimer()
				flushPending()

			}
		case <-timerC:
			timer = nil
			timerC = nil
			flushPending()

		}
	}
}
