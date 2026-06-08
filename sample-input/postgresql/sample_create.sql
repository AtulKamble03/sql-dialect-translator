-- Sample PostgreSQL file
-- Used for testing dialect detection and translation

CREATE TABLE policy (
    policy_id      SERIAL          PRIMARY KEY,
    policy_number  VARCHAR(50)     NOT NULL UNIQUE,
    customer_id    INTEGER         NOT NULL,
    premium_amount NUMERIC(18,2)   NOT NULL,
    is_active      BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policy_customer ON policy (customer_id);

SELECT
    p.policy_id,
    p.policy_number,
    COALESCE(p.premium_amount, 0) AS premium_amount,
    EXTRACT(DAY FROM NOW() - p.created_at) AS days_active
FROM policy p
WHERE p.is_active = TRUE
ORDER BY p.created_at DESC
LIMIT 10;
