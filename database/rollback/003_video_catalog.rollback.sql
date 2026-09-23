SET NOCOUNT ON;
SET XACT_ABORT ON;

IF N'$(ConfirmDestructiveRollback)' <> N'YES'
    THROW 50901, 'Destructive rollback refused. Set ConfirmDestructiveRollback=YES after backup and approval.', 1;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50902, 'Refusing to roll back the video catalog in a system database.', 1;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber > '003')
    THROW 50903, 'A later schema version is installed. Do not roll back version 003 independently.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.FK_Votes_Videos_VideoId', N'F') IS NOT NULL
        ALTER TABLE dbo.Votes DROP CONSTRAINT FK_Votes_Videos_VideoId;

    IF OBJECT_ID(N'dbo.FK_WatchSessions_Videos_VideoId', N'F') IS NOT NULL
        ALTER TABLE dbo.WatchSessions DROP CONSTRAINT FK_WatchSessions_Videos_VideoId;

    IF OBJECT_ID(N'dbo.Videos', N'U') IS NOT NULL
        DROP TABLE dbo.Videos;

    DELETE dbo.SchemaVersions WHERE VersionNumber = '003';

    COMMIT TRANSACTION;
    PRINT 'GreenCare video catalog rollback completed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
