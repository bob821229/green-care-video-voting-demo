SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51201, 'Refusing to update the video catalog in a system database.', 1;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '003')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '004')
    THROW 51202, 'Schema versions 003 and 004 are required before version 005.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '005')
    BEGIN
        IF OBJECT_ID(N'dbo.CK_Videos_IdCategory', N'C') IS NOT NULL
           OR OBJECT_ID(N'dbo.CK_Votes_VideoCategory', N'C') IS NOT NULL
           OR OBJECT_ID(N'dbo.CK_WatchSessions_VideoId', N'C') IS NOT NULL
            THROW 51203, 'Schema version 005 is recorded but fixed catalog constraints remain.', 1;

        COMMIT TRANSACTION;
        PRINT 'Schema version 005 is already installed.';
        RETURN;
    END;

    IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
       OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
        THROW 51204, 'Required catalog tables are missing.', 1;

    IF OBJECT_ID(N'dbo.CK_Videos_Id', N'C') IS NOT NULL
        ALTER TABLE dbo.Videos DROP CONSTRAINT CK_Videos_Id;
    IF OBJECT_ID(N'dbo.CK_Videos_IdCategory', N'C') IS NOT NULL
        ALTER TABLE dbo.Videos DROP CONSTRAINT CK_Videos_IdCategory;
    IF OBJECT_ID(N'dbo.CK_Videos_SortOrder', N'C') IS NOT NULL
        ALTER TABLE dbo.Videos DROP CONSTRAINT CK_Videos_SortOrder;
    IF OBJECT_ID(N'dbo.CK_Votes_VideoId', N'C') IS NOT NULL
        ALTER TABLE dbo.Votes DROP CONSTRAINT CK_Votes_VideoId;
    IF OBJECT_ID(N'dbo.CK_Votes_VideoCategory', N'C') IS NOT NULL
        ALTER TABLE dbo.Votes DROP CONSTRAINT CK_Votes_VideoCategory;
    IF OBJECT_ID(N'dbo.CK_WatchSessions_VideoId', N'C') IS NOT NULL
        ALTER TABLE dbo.WatchSessions DROP CONSTRAINT CK_WatchSessions_VideoId;

    ALTER TABLE dbo.Videos WITH CHECK
        ADD CONSTRAINT CK_Videos_SortOrder CHECK (SortOrder >= 1);
    ALTER TABLE dbo.Videos CHECK CONSTRAINT CK_Videos_SortOrder;

    INSERT dbo.SchemaVersions (VersionNumber, Description)
    VALUES ('005', N'Dynamic video catalog category and ordering');

    COMMIT TRANSACTION;
    PRINT 'Schema version 005 installed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
