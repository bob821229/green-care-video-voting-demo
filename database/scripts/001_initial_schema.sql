SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50001, 'Refusing to install GreenCare schema in a system database.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.SchemaVersions
        (
            VersionNumber varchar(20) NOT NULL,
            Description nvarchar(200) NOT NULL,
            AppliedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_SchemaVersions_AppliedAtUtc DEFAULT SYSUTCDATETIME(),
            AppliedBy sysname NOT NULL
                CONSTRAINT DF_SchemaVersions_AppliedBy DEFAULT ORIGINAL_LOGIN(),
            CONSTRAINT PK_SchemaVersions PRIMARY KEY CLUSTERED (VersionNumber)
        );
    END;

    IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '001')
    BEGIN
        IF OBJECT_ID(N'dbo.Devices', N'U') IS NULL
           OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
           OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
           OR OBJECT_ID(N'dbo.RiskEvents', N'U') IS NULL
           OR OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
            THROW 50002, 'Schema version 001 is recorded but required objects are missing.', 1;

        COMMIT TRANSACTION;
        PRINT 'Schema version 001 is already installed.';
        RETURN;
    END;

    IF OBJECT_ID(N'dbo.Devices', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.Votes', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.RiskEvents', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.AuditLogs', N'U') IS NOT NULL
        THROW 50003, 'One or more GreenCare tables already exist without schema version 001.', 1;

    CREATE TABLE dbo.Devices
    (
        Id uniqueidentifier NOT NULL,
        CreatedAtUtc datetime2(3) NOT NULL,
        LastSeenAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_Devices PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT CK_Devices_LastSeenAfterCreated CHECK (LastSeenAtUtc >= CreatedAtUtc)
    );

    CREATE TABLE dbo.WatchSessions
    (
        Id uniqueidentifier NOT NULL,
        DeviceId uniqueidentifier NOT NULL,
        VideoId tinyint NOT NULL,
        DurationSeconds decimal(10,3) NOT NULL,
        WatchedSeconds decimal(10,3) NOT NULL
            CONSTRAINT DF_WatchSessions_WatchedSeconds DEFAULT (0),
        LastPositionSeconds decimal(10,3) NOT NULL
            CONSTRAINT DF_WatchSessions_LastPositionSeconds DEFAULT (0),
        LastPingAtUtc datetime2(3) NOT NULL,
        QualifiedAtUtc datetime2(3) NULL,
        CreatedAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_WatchSessions PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_WatchSessions_Devices_DeviceId FOREIGN KEY (DeviceId)
            REFERENCES dbo.Devices (Id),
        CONSTRAINT CK_WatchSessions_VideoId CHECK (VideoId BETWEEN 1 AND 30),
        CONSTRAINT CK_WatchSessions_Duration CHECK (DurationSeconds BETWEEN 10 AND 7200),
        CONSTRAINT CK_WatchSessions_Watched CHECK
            (WatchedSeconds >= 0 AND WatchedSeconds <= DurationSeconds),
        CONSTRAINT CK_WatchSessions_LastPosition CHECK
            (LastPositionSeconds >= 0 AND LastPositionSeconds <= DurationSeconds),
        CONSTRAINT CK_WatchSessions_QualifiedAfterCreated CHECK
            (QualifiedAtUtc IS NULL OR QualifiedAtUtc >= CreatedAtUtc)
    );

    CREATE INDEX IX_WatchSessions_Device_Video
        ON dbo.WatchSessions (DeviceId, VideoId)
        INCLUDE (QualifiedAtUtc, WatchedSeconds, DurationSeconds, LastPingAtUtc);

    CREATE TABLE dbo.Votes
    (
        Id bigint IDENTITY(1,1) NOT NULL,
        DeviceId uniqueidentifier NOT NULL,
        VideoId tinyint NOT NULL,
        Category varchar(10) NOT NULL,
        WatchSessionId uniqueidentifier NOT NULL,
        IpHash binary(32) NOT NULL,
        DeviceSignalHash binary(32) NULL,
        RiskScore tinyint NOT NULL
            CONSTRAINT DF_Votes_RiskScore DEFAULT (0),
        Status varchar(10) NOT NULL
            CONSTRAINT DF_Votes_Status DEFAULT ('valid'),
        CreatedAtUtc datetime2(3) NOT NULL,
        CancelledAtUtc datetime2(3) NULL,
        ReplacedByVoteId bigint NULL,
        VoidedAtUtc datetime2(3) NULL,
        VoidReason nvarchar(300) NULL,
        IsActive AS
            (CASE WHEN Status IN ('valid', 'flagged') THEN CONVERT(bit, (1)) ELSE CONVERT(bit, (0)) END)
            PERSISTED,
        CONSTRAINT PK_Votes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Votes_Devices_DeviceId FOREIGN KEY (DeviceId)
            REFERENCES dbo.Devices (Id),
        CONSTRAINT FK_Votes_WatchSessions_WatchSessionId FOREIGN KEY (WatchSessionId)
            REFERENCES dbo.WatchSessions (Id),
        CONSTRAINT FK_Votes_Votes_ReplacedByVoteId FOREIGN KEY (ReplacedByVoteId)
            REFERENCES dbo.Votes (Id),
        CONSTRAINT CK_Votes_VideoId CHECK (VideoId BETWEEN 1 AND 30),
        CONSTRAINT CK_Votes_Category CHECK (Category IN ('individual', 'team')),
        CONSTRAINT CK_Votes_VideoCategory CHECK
            ((VideoId BETWEEN 1 AND 15 AND Category = 'individual')
             OR (VideoId BETWEEN 16 AND 30 AND Category = 'team')),
        CONSTRAINT CK_Votes_RiskScore CHECK (RiskScore BETWEEN 0 AND 100),
        CONSTRAINT CK_Votes_Status CHECK (Status IN ('valid', 'flagged', 'cancelled', 'void')),
        CONSTRAINT CK_Votes_CancelledState CHECK
            ((Status = 'cancelled' AND CancelledAtUtc IS NOT NULL)
             OR (Status <> 'cancelled' AND CancelledAtUtc IS NULL)),
        CONSTRAINT CK_Votes_VoidedState CHECK
            ((Status = 'void' AND VoidedAtUtc IS NOT NULL AND NULLIF(LTRIM(RTRIM(VoidReason)), N'') IS NOT NULL)
             OR (Status <> 'void' AND VoidedAtUtc IS NULL AND VoidReason IS NULL)),
        CONSTRAINT CK_Votes_ReplacedVoteState CHECK
            (ReplacedByVoteId IS NULL OR (Status = 'cancelled' AND ReplacedByVoteId <> Id))
    );

    CREATE UNIQUE INDEX UX_Votes_Device_Video_Active
        ON dbo.Votes (DeviceId, VideoId)
        WHERE CancelledAtUtc IS NULL AND VoidedAtUtc IS NULL;

    CREATE INDEX IX_Votes_Device_Category_Status
        ON dbo.Votes (DeviceId, Category, Status)
        INCLUDE (VideoId, CreatedAtUtc);

    CREATE INDEX IX_Votes_Video_Status
        ON dbo.Votes (VideoId, Status)
        INCLUDE (CreatedAtUtc);

    CREATE INDEX IX_Votes_IpHash_CreatedAtUtc
        ON dbo.Votes (IpHash, CreatedAtUtc);

    CREATE TABLE dbo.RiskEvents
    (
        Id bigint IDENTITY(1,1) NOT NULL,
        DeviceId uniqueidentifier NULL,
        IpHash binary(32) NULL,
        Kind varchar(50) NOT NULL,
        DetailJson nvarchar(max) NULL,
        CreatedAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_RiskEvents PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_RiskEvents_Devices_DeviceId FOREIGN KEY (DeviceId)
            REFERENCES dbo.Devices (Id),
        CONSTRAINT CK_RiskEvents_DetailJson CHECK (DetailJson IS NULL OR ISJSON(DetailJson) = 1)
    );

    CREATE INDEX IX_RiskEvents_Device_CreatedAtUtc
        ON dbo.RiskEvents (DeviceId, CreatedAtUtc);

    CREATE INDEX IX_RiskEvents_IpHash_CreatedAtUtc
        ON dbo.RiskEvents (IpHash, CreatedAtUtc);

    CREATE TABLE dbo.AuditLogs
    (
        Id bigint IDENTITY(1,1) NOT NULL,
        Action varchar(50) NOT NULL,
        Target nvarchar(200) NOT NULL,
        DetailJson nvarchar(max) NULL,
        CreatedAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_AuditLogs PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT CK_AuditLogs_DetailJson CHECK (DetailJson IS NULL OR ISJSON(DetailJson) = 1)
    );

    CREATE INDEX IX_AuditLogs_Action_CreatedAtUtc
        ON dbo.AuditLogs (Action, CreatedAtUtc);

    INSERT dbo.SchemaVersions (VersionNumber, Description)
    VALUES ('001', N'Initial GreenCare voting schema');

    COMMIT TRANSACTION;
    PRINT 'Schema version 001 installed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
