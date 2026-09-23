SET NOCOUNT ON;
SET XACT_ABORT ON;

IF N'$(ConfirmDestructiveRollback)' <> N'YES'
    THROW 50601, 'Destructive rollback refused. Set ConfirmDestructiveRollback=YES after backup and approval.', 1;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50602, 'Refusing to roll back GreenCare schema in a system database.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @member sysname;
    DECLARE role_members CURSOR LOCAL FAST_FORWARD FOR
        SELECT member_principal.name
        FROM sys.database_role_members role_membership
        JOIN sys.database_principals role_principal
          ON role_principal.principal_id = role_membership.role_principal_id
        JOIN sys.database_principals member_principal
          ON member_principal.principal_id = role_membership.member_principal_id
        WHERE role_principal.name = N'GreenCareAppRole';

    OPEN role_members;
    FETCH NEXT FROM role_members INTO @member;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @dropMemberSql nvarchar(max) =
            N'ALTER ROLE GreenCareAppRole DROP MEMBER ' + QUOTENAME(@member) + N';';
        EXEC sys.sp_executesql @dropMemberSql;
        FETCH NEXT FROM role_members INTO @member;
    END;
    CLOSE role_members;
    DEALLOCATE role_members;

    IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NOT NULL
        DROP ROLE GreenCareAppRole;

    DROP TABLE IF EXISTS dbo.RiskEvents;
    DROP TABLE IF EXISTS dbo.AuditLogs;
    DROP TABLE IF EXISTS dbo.Votes;
    DROP TABLE IF EXISTS dbo.WatchSessions;
    DROP TABLE IF EXISTS dbo.Videos;
    DROP TABLE IF EXISTS dbo.Devices;
    DROP TABLE IF EXISTS dbo.SchemaVersions;

    COMMIT TRANSACTION;
    PRINT 'GreenCare initial schema rollback completed.';
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'role_members') >= -1
    BEGIN
        CLOSE role_members;
        DEALLOCATE role_members;
    END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
