SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF OBJECT_ID(N'dbo.RiskEvents', N'U') IS NULL OR OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
    THROW 51501, 'RiskEvents or AuditLogs table is missing.', 1;

SELECT
    risk.Id AS RiskEventId,
    risk.Kind,
    risk.DeviceId,
    CASE WHEN risk.IpHash IS NULL THEN NULL
         ELSE CONVERT(varchar(64), risk.IpHash, 2)
    END AS IpHashHex,
    risk.DetailJson,
    risk.CreatedAtUtc,
    risk.CreatedAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Taipei Standard Time' AS CreatedAtTaipei
FROM dbo.RiskEvents AS risk
ORDER BY risk.Id;

SELECT
    audit.Id AS AuditLogId,
    audit.Action,
    audit.Target,
    audit.DetailJson,
    audit.CreatedAtUtc,
    audit.CreatedAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Taipei Standard Time' AS CreatedAtTaipei
FROM dbo.AuditLogs AS audit
ORDER BY audit.Id;
