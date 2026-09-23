SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50801, 'Refusing to verify the video catalog in a system database.', 1;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
    THROW 50802, 'Videos table is missing.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '003')
    THROW 50803, 'Schema version 003 is not installed.', 1;

IF (SELECT COUNT(*) FROM dbo.Videos) <> 30
    THROW 50804, 'Videos must contain exactly 30 rows.', 1;

IF (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'individual') <> 15
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'team') <> 15
    THROW 50805, 'Videos must contain 15 individual and 15 team entries.', 1;

IF EXISTS
(
    SELECT expected.Id
    FROM
    (
        VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
               (11),(12),(13),(14),(15),(16),(17),(18),(19),(20),
               (21),(22),(23),(24),(25),(26),(27),(28),(29),(30)
    ) AS expected(Id)
    LEFT JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Id IS NULL
)
    THROW 50806, 'Videos must contain every ID from 1 through 30.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name IN (N'FK_WatchSessions_Videos_VideoId', N'FK_Votes_Videos_VideoId')
      AND (is_disabled = 1 OR is_not_trusted = 1)
)
    THROW 50807, 'One or more video catalog foreign keys are disabled or untrusted.', 1;

IF (SELECT COUNT(*) FROM sys.foreign_keys
    WHERE name IN (N'FK_WatchSessions_Videos_VideoId', N'FK_Votes_Videos_VideoId')) <> 2
    THROW 50808, 'Expected video catalog foreign keys are missing.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
    THROW 50809, 'GreenCareAppRole is missing.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCareVideoPermissionProbe') IS NOT NULL
    DROP USER GreenCareVideoPermissionProbe;

CREATE USER GreenCareVideoPermissionProbe WITHOUT LOGIN;
ALTER ROLE GreenCareAppRole ADD MEMBER GreenCareVideoPermissionProbe;

DECLARE @CanSelect int;
DECLARE @CanInsert int;
DECLARE @CanUpdate int;
DECLARE @CanDelete int;

EXECUTE AS USER = N'GreenCareVideoPermissionProbe';
SELECT @CanSelect = HAS_PERMS_BY_NAME(N'dbo.Videos', N'OBJECT', N'SELECT');
SELECT @CanInsert = HAS_PERMS_BY_NAME(N'dbo.Videos', N'OBJECT', N'INSERT');
SELECT @CanUpdate = HAS_PERMS_BY_NAME(N'dbo.Videos', N'OBJECT', N'UPDATE');
SELECT @CanDelete = HAS_PERMS_BY_NAME(N'dbo.Videos', N'OBJECT', N'DELETE');
REVERT;

ALTER ROLE GreenCareAppRole DROP MEMBER GreenCareVideoPermissionProbe;
DROP USER GreenCareVideoPermissionProbe;

IF @CanSelect <> 1
    THROW 50810, 'GreenCareAppRole cannot read Videos.', 1;

IF @CanInsert <> 0 OR @CanUpdate <> 0 OR @CanDelete <> 0
    THROW 50811, 'GreenCareAppRole has unexpected write permission on Videos.', 1;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
WHERE VersionNumber = '003';

SELECT Id, Number, Title, Team, YoutubeId, Poster, Category, SortOrder, IsActive
FROM dbo.Videos
ORDER BY Id;

PRINT 'GreenCare video catalog verification passed.';
