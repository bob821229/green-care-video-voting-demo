SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50101, 'Refusing to install GreenCare permissions in a system database.', 1;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
    THROW 50102, 'SchemaVersions is missing. Run 001_initial_schema.sql first.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '001')
    THROW 50103, 'Schema version 001 is required before version 002.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '002')
    BEGIN
        IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
            THROW 50104, 'Schema version 002 is recorded but GreenCareAppRole is missing.', 1;

        COMMIT TRANSACTION;
        PRINT 'Schema version 002 is already installed.';
        RETURN;
    END;

    IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
        CREATE ROLE GreenCareAppRole AUTHORIZATION dbo;

    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Devices TO GreenCareAppRole;
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.WatchSessions TO GreenCareAppRole;
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Votes TO GreenCareAppRole;
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.RiskEvents TO GreenCareAppRole;
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLogs TO GreenCareAppRole;
    GRANT SELECT ON dbo.SchemaVersions TO GreenCareAppRole;

    DENY ALTER ON SCHEMA::dbo TO GreenCareAppRole;

    INSERT dbo.SchemaVersions (VersionNumber, Description)
    VALUES ('002', N'Application least-privilege database role');

    COMMIT TRANSACTION;
    PRINT 'Schema version 002 installed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
