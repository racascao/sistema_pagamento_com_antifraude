-- +goose Up
-- Manual review cases produced by the fraud pipeline and enriched by
-- the investigator agent outside the synchronous path.
CREATE TABLE reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id  UUID NOT NULL REFERENCES payments (id),
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'investigating', 'resolved')),
    report      TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reviews_status_idx ON reviews (status, created_at);

-- +goose Down
DROP TABLE reviews;
