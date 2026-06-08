-- Sample SQL Server (T-SQL) file
-- Used for testing dialect detection and translation

CREATE TABLE dbo.policy (
    policy_id      INT           IDENTITY(1,1) PRIMARY KEY,
    policy_number  NVARCHAR(50)  NOT NULL UNIQUE,
    customer_id    INT           NOT NULL,
    premium_amount DECIMAL(18,2) NOT NULL,
    is_active      BIT           NOT NULL DEFAULT 1,
    created_at     DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

CREATE INDEX idx_policy_customer ON dbo.policy (customer_id);
GO

SELECT TOP 10
    p.policy_id,
    p.policy_number,
    ISNULL(p.premium_amount, 0) AS premium_amount,
    DATEDIFF(DAY, p.created_at, GETDATE()) AS days_active
FROM dbo.policy p WITH (NOLOCK)
WHERE p.is_active = 1
ORDER BY p.created_at DESC;
GO
