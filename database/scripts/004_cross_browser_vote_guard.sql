SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51001, 'Refusing to install the cross-browser vote guard in a system database.', 1;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
    THROW 51002, 'SchemaVersions is missing. Run 001_initial_schema.sql first.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '001')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '002')
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '003')
    THROW 51003, 'Schema versions 001, 002, and 003 are required before version 004.', 1;

IF OBJECT_ID(N'dbo.Votes', N'U') IS NULL
    THROW 51004, 'Votes is missing. Run the earlier schema scripts first.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '004')
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.Votes')
              AND name = N'IX_Votes_Environment_Category_Status'
        )
            THROW 51005, 'Schema version 004 is recorded but its vote environment index is missing.', 1;

        COMMIT TRANSACTION;
        PRINT 'Schema version 004 is already installed.';
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Votes')
          AND name = N'IX_Votes_Environment_Category_Status'
    )
        THROW 51006, 'The vote environment index exists without schema version 004.', 1;

    CREATE INDEX IX_Votes_Environment_Category_Status
        ON dbo.Votes (IpHash, DeviceSignalHash, Category, Status)
        INCLUDE (DeviceId, VideoId, CreatedAtUtc);

    INSERT dbo.SchemaVersions (VersionNumber, Description)
    VALUES ('004', N'Cross-browser vote guard environment lookup index');

    COMMIT TRANSACTION;
    PRINT 'Schema version 004 installed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
