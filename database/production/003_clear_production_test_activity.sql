USE [GreenCare_Production];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

/*
  This script removes test activity only. It preserves Videos, SchemaVersions,
  database users, roles, schema objects, and application configuration.

  Keep @Execute = 0 for a read-only preview. To perform the cleanup, set
  @Execute = 1 and enter the exact confirmation phrase below.
*/
DECLARE @Execute bit = 0;
DECLARE @Confirmation nvarchar(100) = N'';
DECLARE @RequiredConfirmation nvarchar(100) =
    N'CLEAR GREENCARE PRODUCTION TEST ACTIVITY';

IF DB_NAME() <> N'GreenCare_Production'
    THROW 51020, 'This script may run only in GreenCare_Production.', 1;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Devices', N'U') IS NULL
   OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.RiskEvents', N'U') IS NULL
   OR OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
    THROW 51021, 'Required GreenCare tables are missing.', 1;

IF (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1) <> 27
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'individual') <> 13
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'team') <> 14
    THROW 51022, 'Official catalog verification failed; no activity data was changed.', 1;

SELECT
    DB_NAME() AS DatabaseName,
    CASE WHEN @Execute = 1 THEN N'EXECUTE' ELSE N'PREVIEW' END AS Mode,
    (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1) AS ActiveVideoCount,
    (SELECT COUNT(*) FROM dbo.Devices) AS DeviceCount,
    (SELECT COUNT(*) FROM dbo.WatchSessions) AS WatchSessionCount,
    (SELECT COUNT(*) FROM dbo.Votes) AS VoteCount,
    (SELECT COUNT(*) FROM dbo.RiskEvents) AS RiskEventCount,
    (SELECT COUNT(*) FROM dbo.AuditLogs) AS AuditLogCount;

IF @Execute = 0
BEGIN
    PRINT N'PREVIEW ONLY. Nothing was changed.';
    RETURN;
END;

IF @Confirmation <> @RequiredConfirmation
    THROW 51023, 'Confirmation is missing or incorrect; no activity data was changed.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Break the optional self-reference before deleting every test vote.
    UPDATE dbo.Votes
    SET ReplacedByVoteId = NULL
    WHERE ReplacedByVoteId IS NOT NULL;

    DELETE FROM dbo.Votes;
    DELETE FROM dbo.RiskEvents;
    DELETE FROM dbo.WatchSessions;
    DELETE FROM dbo.AuditLogs;
    DELETE FROM dbo.Devices;

    IF EXISTS (SELECT 1 FROM dbo.Votes)
       OR EXISTS (SELECT 1 FROM dbo.RiskEvents)
       OR EXISTS (SELECT 1 FROM dbo.WatchSessions)
       OR EXISTS (SELECT 1 FROM dbo.AuditLogs)
       OR EXISTS (SELECT 1 FROM dbo.Devices)
        THROW 51024, 'Cleanup verification failed; the transaction will be rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT
    DB_NAME() AS DatabaseName,
    N'CLEARED' AS Result,
    (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1) AS ActiveVideoCount,
    (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'individual') AS IndividualVideoCount,
    (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'team') AS TeamVideoCount,
    (SELECT COUNT(*) FROM dbo.Devices) AS DeviceCount,
    (SELECT COUNT(*) FROM dbo.WatchSessions) AS WatchSessionCount,
    (SELECT COUNT(*) FROM dbo.Votes) AS VoteCount,
    (SELECT COUNT(*) FROM dbo.RiskEvents) AS RiskEventCount,
    (SELECT COUNT(*) FROM dbo.AuditLogs) AS AuditLogCount;

PRINT N'GreenCare_Production test activity cleanup completed.';
GO
