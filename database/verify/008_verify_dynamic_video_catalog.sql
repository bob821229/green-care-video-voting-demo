SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '005')
    THROW 51401, 'Schema version 005 is not installed.', 1;
IF OBJECT_ID(N'dbo.CK_Videos_IdCategory', N'C') IS NOT NULL
   OR OBJECT_ID(N'dbo.CK_Votes_VideoCategory', N'C') IS NOT NULL
   OR OBJECT_ID(N'dbo.CK_WatchSessions_VideoId', N'C') IS NOT NULL
    THROW 51402, 'One or more fixed catalog constraints remain.', 1;
IF OBJECT_ID(N'dbo.CK_Videos_SortOrder', N'C') IS NULL
    THROW 51403, 'Positive sort-order constraint is missing.', 1;
IF OBJECT_ID(N'dbo.FK_WatchSessions_Videos_VideoId', N'F') IS NULL
   OR OBJECT_ID(N'dbo.FK_Votes_Videos_VideoId', N'F') IS NULL
    THROW 51404, 'Video foreign keys are missing.', 1;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
WHERE VersionNumber = '005';

PRINT 'Dynamic video catalog verification passed.';
