SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51101, 'Refusing to export from a system database.', 1;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Devices', N'U') IS NULL
   OR OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
    THROW 51102, 'Required GreenCare tables are missing.', 1;

SELECT
    DB_NAME() AS DatabaseName,
    @@SERVERNAME AS ServerName,
    SYSUTCDATETIME() AS GeneratedAtUtc,
    SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Taipei Standard Time' AS GeneratedAtTaipei,
    (SELECT COUNT(*) FROM dbo.Videos) AS VideoCount,
    (SELECT COUNT(*) FROM dbo.Devices) AS DeviceCount,
    (SELECT COUNT(*) FROM dbo.WatchSessions) AS WatchSessionCount,
    (SELECT COUNT(*) FROM dbo.Votes) AS VoteRecordCount,
    (SELECT COUNT(*) FROM dbo.Votes WHERE Status = 'valid') AS ValidVoteCount,
    (SELECT COUNT(*) FROM dbo.Votes WHERE Status = 'flagged') AS FlaggedVoteCount,
    (SELECT COUNT(*) FROM dbo.Votes WHERE Status = 'cancelled') AS CancelledVoteCount,
    (SELECT COUNT(*) FROM dbo.Votes WHERE Status = 'void') AS VoidVoteCount;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
ORDER BY VersionNumber;
