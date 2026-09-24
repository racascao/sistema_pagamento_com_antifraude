-- +goose Up
CREATE TABLE payments (
    id                 UUID PRIMARY KEY,
    account_id         UUID NOT NULL REFERENCES accounts (id),
    card_fingerprint   TEXT NOT NULL,
    amount_cents       BIGINT NOT NULL CHECK (amount_cents > 0),
    currency           CHAR(3) NOT NULL,
    status             TEXT NOT NULL CHECK (status IN ('approved', 'denied', 'manual_review')),
    risk_score         DOUBLE PRECISION NOT NULL DEFAULT 0,
    reasons            TEXT[] NOT NULL DEFAULT '{}',
    client_ip          TEXT NOT NULL DEFAULT '',
    merchant_category  TEXT NOT NULL DEFAULT '',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX payments_account_created_idx ON payments (account_id, created_at DESC);

-- Ledger entries follow double entry accounting. Every payment writes
-- exactly two rows: a debit and a credit. The trigger below rejects
-- any transaction whose entries do not sum to zero.
CREATE TABLE ledger_entries (
    id           BIGSERIAL PRIMARY KEY,
    payment_id   UUID NOT NULL REFERENCES payments (id),
    account_id   UUID NOT NULL REFERENCES accounts (id),
    direction    TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
    amount_cents BIGINT NOT NULL CHECK (amount_cents > 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ledger_entries_payment_idx ON ledger_entries (payment_id);

-- +goose StatementBegin
CREATE FUNCTION check_double_entry() RETURNS trigger AS $$
DECLARE
    balance BIGINT;
BEGIN
    SELECT COALESCE(SUM(CASE direction WHEN 'debit' THEN amount_cents ELSE -amount_cents END), 0)
    INTO balance
    FROM ledger_entries
    WHERE payment_id = NEW.payment_id;

    IF balance <> 0 THEN
        RAISE EXCEPTION 'ledger entries for payment % do not balance: %', NEW.payment_id, balance;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

CREATE CONSTRAINT TRIGGER ledger_entries_balanced
    AFTER INSERT ON ledger_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_double_entry();

-- +goose Down
DROP TRIGGER ledger_entries_balanced ON ledger_entries;
DROP FUNCTION check_double_entry;
DROP TABLE ledger_entries;
DROP TABLE payments;
