-- +goose Up
-- Human decisions close the review loop. The agent produces a
-- recommendation, a person applies the final decision. Closed is a
-- terminal state: one decision per review, enforced by the guarded
-- update in the repository.
ALTER TABLE reviews DROP CONSTRAINT reviews_status_check;
ALTER TABLE reviews ADD CONSTRAINT reviews_status_check
    CHECK (status IN ('pending', 'investigating', 'resolved', 'closed'));

ALTER TABLE reviews
    ADD COLUMN recommendation TEXT NOT NULL DEFAULT '',
    ADD COLUMN decision       TEXT NOT NULL DEFAULT ''
        CHECK (decision IN ('', 'approved', 'denied')),
    ADD COLUMN decided_by     TEXT NOT NULL DEFAULT '',
    ADD COLUMN decided_at     TIMESTAMPTZ;

-- +goose Down
ALTER TABLE reviews
    DROP COLUMN decided_at,
    DROP COLUMN decided_by,
    DROP COLUMN decision,
    DROP COLUMN recommendation;

ALTER TABLE reviews DROP CONSTRAINT reviews_status_check;
ALTER TABLE reviews ADD CONSTRAINT reviews_status_check
    CHECK (status IN ('pending', 'investigating', 'resolved'));
