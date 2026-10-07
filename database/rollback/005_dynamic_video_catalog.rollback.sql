SET NOCOUNT ON;
SET XACT_ABORT ON;

IF N'$(ConfirmDestructiveRollback)' <> N'YES'
    THROW 51301, 'Rollback refused. Set ConfirmDestructiveRollback=YES after approval.', 1;
IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber > '005')
    THROW 51302, 'A later schema version is installed. Do not roll back version 005 independently.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Videos
    WHERE Id NOT BETWEEN 1 AND 30
       OR (Id BETWEEN 1 AND 15 AND Category <> 'individual')
       OR (Id BETWEEN 16 AND 30 AND Category <> 'team')
       OR SortOrder NOT BETWEEN 1 AND 15
)
    THROW 51303, 'Current catalog no longer satisfies the legacy 30-work layout.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE dbo.Videos DROP CONSTRAINT CK_Videos_SortOrder;
    ALTER TABLE dbo.Videos WITH CHECK ADD CONSTRAINT CK_Videos_Id CHECK (Id BETWEEN 1 AND 30);
    ALTER TABLE dbo.Videos WITH CHECK ADD CONSTRAINT CK_Videos_IdCategory CHECK
        ((Id BETWEEN 1 AND 15 AND Category = 'individual') OR
         (Id BETWEEN 16 AND 30 AND Category = 'team'));
    ALTER TABLE dbo.Videos WITH CHECK ADD CONSTRAINT CK_Videos_SortOrder CHECK (SortOrder BETWEEN 1 AND 15);
    ALTER TABLE dbo.Votes WITH CHECK ADD CONSTRAINT CK_Votes_VideoId CHECK (VideoId BETWEEN 1 AND 30);
    ALTER TABLE dbo.Votes WITH CHECK ADD CONSTRAINT CK_Votes_VideoCategory CHECK
        ((VideoId BETWEEN 1 AND 15 AND Category = 'individual') OR
         (VideoId BETWEEN 16 AND 30 AND Category = 'team'));
    ALTER TABLE dbo.WatchSessions WITH CHECK ADD CONSTRAINT CK_WatchSessions_VideoId CHECK (VideoId BETWEEN 1 AND 30);

    DELETE dbo.SchemaVersions WHERE VersionNumber = '005';

    COMMIT TRANSACTION;
    PRINT 'Schema version 005 rollback completed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
