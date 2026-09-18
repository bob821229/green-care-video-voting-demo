SET NOCOUNT ON;
-- Expected constraint violations are caught below, so this verification transaction
-- must remain committable long enough to execute all assertions before rollback.
SET XACT_ABORT OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @DeviceId uniqueidentifier = NEWID();
    DECLARE @WatchOne uniqueidentifier = NEWID();
    DECLARE @WatchTwo uniqueidentifier = NEWID();
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @DuplicateBlocked bit = 0;
    DECLARE @InvalidCategoryBlocked bit = 0;

    INSERT dbo.Devices (Id, CreatedAtUtc, LastSeenAtUtc)
    VALUES (@DeviceId, @Now, @Now);

    INSERT dbo.WatchSessions
        (Id, DeviceId, VideoId, DurationSeconds, WatchedSeconds, LastPositionSeconds,
         LastPingAtUtc, QualifiedAtUtc, CreatedAtUtc)
    VALUES
        (@WatchOne, @DeviceId, 1, 100, 80, 80, @Now, @Now, @Now),
        (@WatchTwo, @DeviceId, 2, 100, 80, 80, @Now, @Now, @Now);

    INSERT dbo.Votes
        (DeviceId, VideoId, Category, WatchSessionId, IpHash, RiskScore, Status, CreatedAtUtc)
    VALUES
        (@DeviceId, 1, 'individual', @WatchOne, HASHBYTES('SHA2_256', 'test-ip'), 0, 'valid', @Now);

    BEGIN TRY
        INSERT dbo.Votes
            (DeviceId, VideoId, Category, WatchSessionId, IpHash, RiskScore, Status, CreatedAtUtc)
        VALUES
            (@DeviceId, 1, 'individual', @WatchOne, HASHBYTES('SHA2_256', 'test-ip'), 0, 'flagged', @Now);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627) SET @DuplicateBlocked = 1;
        ELSE THROW;
    END CATCH;

    BEGIN TRY
        INSERT dbo.Votes
            (DeviceId, VideoId, Category, WatchSessionId, IpHash, RiskScore, Status, CreatedAtUtc)
        VALUES
            (@DeviceId, 2, 'team', @WatchTwo, HASHBYTES('SHA2_256', 'test-ip'), 0, 'valid', @Now);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 547 SET @InvalidCategoryBlocked = 1;
        ELSE THROW;
    END CATCH;

    IF @DuplicateBlocked <> 1
        THROW 50501, 'Duplicate active vote was not blocked.', 1;

    IF @InvalidCategoryBlocked <> 1
        THROW 50502, 'Invalid video/category combination was not blocked.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'GreenCare constraint verification passed; test transaction rolled back.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
