package fsm_test

import (
	"context"
	"errors"
	"testing"

	"github.com/racascao/payment-processor-course/pkg/fsm"
)

type payload struct {
	visited []string
	score   float64
}

func record(p *payload, name string) {
	p.visited = append(p.visited, name)
}

func TestRun(t *testing.T) {
	tests := []struct {
		name      string
		wantTrace int
		wantScore float64
	}{
		{name: "happy path", wantTrace: 2, wantScore: 0.9},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			machine := fsm.New[payload]("start").
				Handle("start", func(_ context.Context, p *payload) (fsm.State, error) {
					record(p, "start")
					return "score", nil
				}).
				Handle("score", func(_ context.Context, p *payload) (fsm.State, error) {
					record(p, "score")
					p.score = 0.9
					return "done", nil
				}).
				Terminal("done")

			p := payload{}
			trace, err := machine.Run(context.Background(), &p)
			if err != nil {
				t.Fatalf("Run() error = %v", err)
			}
			if len(trace) != tt.wantTrace {
				t.Fatalf("len(trace) = %d, want %d", len(trace), tt.wantTrace)
			}
			if p.score != tt.wantScore {
				t.Fatalf("p.score = %v, want %v", p.score, tt.wantScore)
			}
		})
	}
}

func TestFallbackKeepsPipelineAvailable(t *testing.T) {
	dependencyDown := errors.New("upstream timeout")
	machine := fsm.New[payload]("start").
		Handle("start", func(_ context.Context, p *payload) (fsm.State, error) {
			record(p, "start")
			return "ml", nil
		}).
		Handle("ml", func(_ context.Context, p *payload) (fsm.State, error) {
			record(p, "ml")
			return "", dependencyDown
		}).
		FallbackTo("ml", "rules_only").
		Handle("rules_only", func(_ context.Context, p *payload) (fsm.State, error) {
			record(p, "rules_only")
			return "done", nil
		}).
		Terminal("done")

	p := payload{}
	trace, err := machine.Run(context.Background(), &p)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if p.visited[len(p.visited)-1] != "rules_only" {
		t.Fatalf("last visited state = %q, want rules_only", p.visited[len(p.visited)-1])
	}
	if trace[1].Err == nil {
		t.Fatal("trace[1].Err = nil, want dependency error")
	}
}

func TestErrorWithoutFallbackAborts(t *testing.T) {
	boom := errors.New("boom")
	machine := fsm.New[payload]("start").
		Handle("start", func(_ context.Context, _ *payload) (fsm.State, error) {
			return "", boom
		}).
		Terminal("done")

	trace, err := machine.Run(context.Background(), &payload{})
	if !errors.Is(err, boom) {
		t.Fatalf("errors.Is(Run() error, boom) = false, error = %v", err)
	}
	if len(trace) != 1 {
		t.Fatalf("len(trace) = %d, want 1", len(trace))
	}
}
