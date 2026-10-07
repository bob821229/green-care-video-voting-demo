SET NOCOUNT ON;
SET XACT_ABORT ON;

IF N'$(ConfirmDestructiveRollback)' <> N'YES'
    THROW 51101, 'Rollback refused. Set ConfirmDestructiveRollback=YES after approval.', 1;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51102, 'Refusing to roll back the cross-browser vote guard in a system database.', 1;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber > '004')
    THROW 51103, 'A later schema version is installed. Do not roll back version 004 independently.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Votes')
          AND name = N'IX_Votes_Environment_Category_Status'
    )
        DROP INDEX IX_Votes_Environment_Category_Status ON dbo.Votes;

    DELETE dbo.SchemaVersions WHERE VersionNumber = '004';

    COMMIT TRANSACTION;
    PRINT 'Cross-browser vote guard rollback completed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
