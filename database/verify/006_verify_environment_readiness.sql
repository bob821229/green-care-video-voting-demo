SET NOCOUNT ON;

/*
  SQLCMD variables:
    ExpectedDatabase       GreenCare_Development or GreenCare_Production
    AppUserName            database user used by IIS; use SKIP only for local structural checks
    RequireEmptyActivity   1 before production launch; 0 for an active test database
    RequireOfficialCatalog 1 before production launch; 0 while Demo data is expected
*/
DECLARE @ExpectedDatabase sysname = N'$(ExpectedDatabase)';
DECLARE @AppUserName sysname = N'$(AppUserName)';
DECLARE @RequireEmptyActivity bit = TRY_CONVERT(bit, '$(RequireEmptyActivity)');
DECLARE @RequireOfficialCatalog bit = TRY_CONVERT(bit, '$(RequireOfficialCatalog)');

IF NULLIF(@ExpectedDatabase, N'') IS NULL OR @RequireEmptyActivity IS NULL OR @RequireOfficialCatalog IS NULL
    THROW 50931, 'Required SQLCMD variables are missing or invalid.', 1;
IF DB_NAME() <> @ExpectedDatabase
    THROW 50932, 'Connected database does not match ExpectedDatabase.', 1;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50933, 'A system database can never pass readiness verification.', 1;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '001')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '002')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '003')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '004')
    THROW 50934, 'Schema versions 001, 002, 003, and 004 are required.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Votes')
      AND name = N'IX_Votes_Environment_Category_Status'
)
    THROW 50943, 'Cross-browser vote guard index is missing.', 1;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.FK_WatchSessions_Videos_VideoId', N'F') IS NULL
   OR OBJECT_ID(N'dbo.FK_Votes_Videos_VideoId', N'F') IS NULL
    THROW 50935, 'Video catalog or trusted foreign keys are missing.', 1;

IF (SELECT COUNT(*) FROM dbo.Videos) <> 30
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'individual' AND IsActive = 1) <> 15
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'team' AND IsActive = 1) <> 15
    THROW 50936, 'Expected 30 active videos: 15 individual and 15 team.', 1;

IF @RequireOfficialCatalog = 1
   AND EXISTS
   (
       SELECT 1 FROM dbo.Videos
       WHERE YoutubeId IN ('YLi5uuy5bw4', 'gDQk3jAY67U')
          OR Poster IN (N'images/posters/individual-demo.jpg', N'images/posters/team-demo.jpg')
   )
    THROW 50937, 'Production readiness failed because Demo video data remains.', 1;

IF @RequireEmptyActivity = 1
   AND
   (
       EXISTS (SELECT 1 FROM dbo.Devices)
       OR EXISTS (SELECT 1 FROM dbo.WatchSessions)
       OR EXISTS (SELECT 1 FROM dbo.Votes)
       OR EXISTS (SELECT 1 FROM dbo.RiskEvents)
       OR EXISTS (SELECT 1 FROM dbo.AuditLogs)
   )
    THROW 50938, 'Production readiness failed because test/activity records exist.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
    THROW 50939, 'GreenCareAppRole is missing.', 1;

IF @AppUserName <> N'SKIP'
BEGIN
    IF DATABASE_PRINCIPAL_ID(@AppUserName) IS NULL
        THROW 50940, 'The configured application database user does not exist.', 1;
    IF IS_ROLEMEMBER(N'GreenCareAppRole', @AppUserName) <> 1
        THROW 50941, 'The application user is not a GreenCareAppRole member.', 1;
    IF IS_ROLEMEMBER(N'db_owner', @AppUserName) = 1
        THROW 50942, 'The application user must not be a db_owner member.', 1;
END;

SELECT
    DB_NAME() AS DatabaseName,
    @AppUserName AS ApplicationUser,
    (SELECT COUNT(*) FROM dbo.Videos) AS VideoCount,
    (SELECT COUNT(*) FROM dbo.Devices) AS DeviceCount,
    (SELECT COUNT(*) FROM dbo.WatchSessions) AS WatchSessionCount,
    (SELECT COUNT(*) FROM dbo.Votes) AS VoteCount,
    (SELECT COUNT(*) FROM dbo.RiskEvents) AS RiskEventCount,
    (SELECT COUNT(*) FROM dbo.AuditLogs) AS AuditLogCount,
    @RequireEmptyActivity AS RequiredEmptyActivity,
    @RequireOfficialCatalog AS RequiredOfficialCatalog;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
ORDER BY VersionNumber;

PRINT 'Environment readiness verification passed.';
