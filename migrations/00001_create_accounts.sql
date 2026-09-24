-- +goose Up
CREATE TABLE accounts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_name  TEXT NOT NULL,
    currency    CHAR(3) NOT NULL DEFAULT 'BRL',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed accounts used by the local environment and the load test.
INSERT INTO accounts (id, owner_name) VALUES
    ('00000000-0000-0000-0000-000000000001', 'merchant settlement'),
    ('00000000-0000-0000-0000-000000000002', 'alice'),
    ('00000000-0000-0000-0000-000000000003', 'bob');

-- +goose Down
DROP TABLE accounts;
