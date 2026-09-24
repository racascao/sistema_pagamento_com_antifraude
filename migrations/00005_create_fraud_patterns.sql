-- +goose Up
CREATE EXTENSION IF NOT EXISTS vector;

-- Historical fraud cases embedded for similarity search. The
-- investigator retrieves the closest cases to ground its analysis.
-- metadata exists because the Genkit postgresql retriever plugin
-- always reads and writes a JSON metadata column alongside the
-- explicit columns; nothing else currently reads it.
CREATE TABLE fraud_patterns (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    summary     TEXT NOT NULL,
    resolution  TEXT NOT NULL,
    embedding   vector(256) NOT NULL,
    metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- HNSW instead of ivfflat: ivfflat computes its centroid lists at
-- index creation time, so an index built on an empty table returns
-- nothing after rows are inserted. HNSW builds incrementally and has
-- no such trap.
CREATE INDEX fraud_patterns_embedding_idx
    ON fraud_patterns USING hnsw (embedding vector_cosine_ops);

-- +goose Down
DROP TABLE fraud_patterns;
