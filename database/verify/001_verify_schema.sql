SET NOCOUNT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50301, 'Refusing to verify GreenCare schema in a system database.', 1;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
    THROW 50302, 'SchemaVersions table is missing.', 1;

IF (SELECT COUNT(*) FROM dbo.SchemaVersions WHERE VersionNumber IN ('001', '002')) <> 2
    THROW 50303, 'Expected schema versions 001 and 002 are not both installed.', 1;

IF OBJECT_ID(N'dbo.Devices', N'U') IS NULL
   OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.RiskEvents', N'U') IS NULL
   OR OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
    THROW 50304, 'One or more required GreenCare tables are missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Votes')
      AND name = N'UX_Votes_Device_Video_Active'
      AND is_unique = 1
      AND has_filter = 1
)
    THROW 50305, 'Active vote unique filtered index is missing or invalid.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.Votes')
      AND name = N'IsActive'
      AND is_computed = 1
      AND is_persisted = 1
)
    THROW 50306, 'Votes.IsActive computed persisted column is missing or invalid.', 1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN
    (OBJECT_ID(N'dbo.WatchSessions'), OBJECT_ID(N'dbo.Votes'), OBJECT_ID(N'dbo.RiskEvents'))) < 5
    THROW 50307, 'Expected foreign keys are missing.', 1;

IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id IN
    (OBJECT_ID(N'dbo.Devices'), OBJECT_ID(N'dbo.WatchSessions'), OBJECT_ID(N'dbo.Votes'),
     OBJECT_ID(N'dbo.RiskEvents'), OBJECT_ID(N'dbo.AuditLogs'))) < 12
    THROW 50308, 'Expected check constraints are missing.', 1;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
ORDER BY VersionNumber;

PRINT 'GreenCare schema verification passed.';
