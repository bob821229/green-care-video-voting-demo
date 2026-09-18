SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50201, 'Refusing to configure an application user in a system database.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
    THROW 50202, 'GreenCareAppRole is missing. Run 002_application_permissions.sql first.', 1;

IF DATABASE_PRINCIPAL_ID(N'$(AppUserName)') IS NULL
    THROW 50203, 'The database user does not exist. A DBA must create it for the approved SQL login or Windows identity first.', 1;

IF IS_ROLEMEMBER(N'GreenCareAppRole', N'$(AppUserName)') <> 1
BEGIN
    DECLARE @statement nvarchar(max) =
        N'ALTER ROLE GreenCareAppRole ADD MEMBER ' + QUOTENAME(N'$(AppUserName)') + N';';
    EXEC sys.sp_executesql @statement;
END;

PRINT 'Application user added to GreenCareAppRole.';
