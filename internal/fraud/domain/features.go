// Package domain defines the fraude scoring model: input features
// rules outcomes, and final decision contract.
package domain

import "time"

// Attempt is the payment attempt as seen by fraud pipeline.
type Attempt struct {
	PaymentID        string
	AccountID        string
	CardFingerPrint  string
	AmountCents      int64
	Currency         string
	ClientIP         string
	MerchantCategory string
	OccuredAt        time.Time

	// Enruched during the pipeline run
	CountryCode     string
	VelocityLastMin int
	RiskScore       float64
	Reasons         []string
	Degraded        bool
}

// Feature names used by the decision tree model
const (
	FeatureAmountCents     = 0
	FeatureVelocityLastMin = 1
	FeatureNightTime       = 2
	FeatureForeignCountry  = 3
	FeatureHighRiskMCC     = 4
	FeatureCount           = 5
)

// HighRisckMerchantCategories flag segments with elevated chargback
// rates in this fictional dataset
var HighRiskMerchantCategories = map[string]bool{
	"gambling":       true,
	"crypto":         true,
	"gift_cards":     true,
	"money_transfer": true,
}

// FeatureVector converts the enriched attempt into the numeric vector
// consumid by the tree model
func FeatureVector(attempt Attempt) []float64 {
	vector := make([]float64, FeatureCount)
	vector[FeatureAmountCents] = float64(attempt.AmountCents)
	vector[FeatureVelocityLastMin] = float64(attempt.VelocityLastMin)
	vector[FeatureNightTime] = 0
	hour := attempt.OccuredAt.Hour()
	if hour >= 0 && hour < 6 {
		vector[FeatureNightTime] = 1
	}
	vector[FeatureForeignCountry] = 0
	if attempt.CountryCode != "" && attempt.CountryCode != "BR" {
		vector[FeatureForeignCountry] = 1
	}
	vector[FeatureHighRiskMCC] = 0
	if HighRiskMerchantCategories[attempt.MerchantCategory] {
		vector[FeatureHighRiskMCC] = 1
	}
	return vector
}

// Verdict values returned by the pipeline
type Verdict string

const (
	VerdictApprove      Verdict = "approve"
	VerdictDeny         Verdict = "deny"
	VerdictManualReview Verdict = "manual_review"
)

// Thresholds convert a continuous risk score into a verdict.
// Scores in the ambiguous band go through the semantic tiebreak stage firts.
const (
	ApproveBelow = 0.35
	DenyAbove    = 0.75
)

// VerdictFromScore applies the banding rule
func VerdictFromScore(score float64) Verdict {
	switch {
	case score < ApproveBelow:
		return VerdictApprove
	case score > DenyAbove:
		return VerdictDeny
	default:
		return VerdictManualReview
	}
}
