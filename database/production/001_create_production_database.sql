USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DatabaseName sysname = N'GreenCare_Production';
DECLARE @Confirmation nvarchar(100) = N'';

IF @Confirmation <> N'CREATE GREENCARE PRODUCTION DATABASE'
BEGIN
    THROW 51000, 'Confirmation is missing. Set @Confirmation before creating the production database.', 1;
END;

IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    THROW 51001, 'GreenCare_Production already exists. Nothing was changed.', 1;
END;

DECLARE @CreateDatabaseSql nvarchar(max) =
    N'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + N';';
DECLARE @SetRecoverySql nvarchar(max) =
    N'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + N' SET RECOVERY FULL;';

EXEC sys.sp_executesql @CreateDatabaseSql;
EXEC sys.sp_executesql @SetRecoverySql;

SELECT
    name AS DatabaseName,
    state_desc AS DatabaseState,
    recovery_model_desc AS RecoveryModel,
    create_date AS CreatedAt
FROM sys.databases
WHERE name = @DatabaseName;

PRINT N'GreenCare_Production was created. Run 002_backup_empty_production_database.sql next.';
GO
