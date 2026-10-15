package domain

type RuleResult struct {
	Verdict Verdict
	Reason  string

	// Final is true when the rule decision cannot be overridden by
	// later stages
	Final bool
}

const (
	MaxAmountCents      = 5_000_000
	VelocityPerMinLimit = 10
)

// Blocklist of card fingerprints known to be compromised.
// A real system loads this from a feed.
// The values exist so the local demo and the test can trigger the path
var Blocklist = map[string]bool{
	"fp_stolen_card_001": true,
	"fp_stolen_card_002": true,
}

// ApplyFastRules runs the deterministic checks that need no model.
func ApplyFastRules(attempt Attempt) RuleResult {

	// Check max amount
	if attempt.AmountCents > MaxAmountCents {
		return RuleResult{
			Verdict: VerdictDeny,
			Reason:  "amount_exceeds_max",
			Final:   true,
		}
	}

	// Check velocity
	if attempt.VelocityLastMin > VelocityPerMinLimit {
		return RuleResult{
			Verdict: VerdictDeny,
			Reason:  "velocity_exceeds_limit",
			Final:   true,
		}
	}

	// Check blocklist
	if Blocklist[attempt.CardFingerPrint] {
		return RuleResult{
			Verdict: VerdictDeny,
			Reason:  "card_blocklisted",
			Final:   true,
		}
	}

	return RuleResult{
		Verdict: VerdictApprove,
		Reason:  "fast_rules_passed",
		Final:   false,
	}
}
