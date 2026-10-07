package fsm

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// State identifies a node in a finite state machine.
type State string

var ErrNoTransition = errors.New("fsm: no transition registered for state")

// Handler is the logic associated with one state.
type Handler[Data any] func(context.Context, *Data) (State, error)

// Transition records one observed hop between states.
type Transition struct {
	From     State
	To       State
	Duration time.Duration
	Err      error
}

// Machine is a deterministic FSM. Build it once and reuse it across goroutines.
// Run state lives in the data argument, not in the machine.
type Machine[Data any] struct {
	initial   State
	terminals map[State]bool
	handlers  map[State]Handler[Data]
	fallbacks map[State]State
	maxHops   int
}

type Option[Data any] func(*Machine[Data])

func WithMaxHops[Data any](n int) Option[Data] {
	return func(machine *Machine[Data]) {
		machine.maxHops = n
	}
}

func New[Data any](initial State, opts ...Option[Data]) *Machine[Data] {
	machine := &Machine[Data]{
		initial:   initial,
		terminals: make(map[State]bool),
		handlers:  make(map[State]Handler[Data]),
		fallbacks: make(map[State]State),
		maxHops:   32,
	}

	for _, option := range opts {
		option(machine)
	}

	return machine
}

func (machine *Machine[Data]) Handle(state State, handler Handler[Data]) *Machine[Data] {
	machine.handlers[state] = handler
	return machine
}

func (machine *Machine[Data]) Terminal(states ...State) *Machine[Data] {
	for _, state := range states {
		machine.terminals[state] = true
	}

	return machine
}

func (machine *Machine[Data]) Run(ctx context.Context, data *Data) ([]Transition, error) {
	trace := make([]Transition, 0, machine.maxHops)
	current := machine.initial

	for hops := 0; hops < machine.maxHops; hops++ {
		if err := ctx.Err(); err != nil {
			return trace, fmt.Errorf("fsm: context canceled at %q: %w", current, err)
		}

		handler, ok := machine.handlers[current]
		if !ok {
			return trace, fmt.Errorf("%w: %q", ErrNoTransition, current)
		}

		startedAt := time.Now()
		next, err := handler(ctx, data)

		transition := Transition{
			From:     current,
			To:       next,
			Duration: time.Since(startedAt),
			Err:      err,
		}

		trace = append(trace, transition)

		if err != nil {
			fallback, hasFallback := machine.fallbacks[current]
			if !hasFallback {
				return trace, fmt.Errorf("fsm: handler at %q: %w", current, err)
			}
			current = fallback
			continue
		}

		if machine.terminals[next] {
			return trace, nil
		}

		current = next
	}

	return trace, fmt.Errorf("fsm: exceeded %d hops stating at %q", machine.maxHops, current)
}

// FallbackTo registers a deterministic escape hatch. When the handler of
// state returns an error, the machine moves to target instead of aborting.
func (machine *Machine[Data]) FallbackTo(states State, target State) *Machine[Data] {
	machine.fallbacks[states] = target
	return machine
}
