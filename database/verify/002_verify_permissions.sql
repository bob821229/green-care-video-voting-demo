SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50401, 'Refusing to verify GreenCare permissions in a system database.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCareAppRole') IS NULL
    THROW 50402, 'GreenCareAppRole is missing.', 1;

IF DATABASE_PRINCIPAL_ID(N'GreenCarePermissionProbe') IS NOT NULL
    DROP USER GreenCarePermissionProbe;

CREATE USER GreenCarePermissionProbe WITHOUT LOGIN;
ALTER ROLE GreenCareAppRole ADD MEMBER GreenCarePermissionProbe;

DECLARE @CanSelectVotes int;
DECLARE @CanInsertVotes int;
DECLARE @CanAlterSchema int;
DECLARE @CanCreateTable int;

EXECUTE AS USER = N'GreenCarePermissionProbe';
SELECT @CanSelectVotes = HAS_PERMS_BY_NAME(N'dbo.Votes', N'OBJECT', N'SELECT');
SELECT @CanInsertVotes = HAS_PERMS_BY_NAME(N'dbo.Votes', N'OBJECT', N'INSERT');
SELECT @CanAlterSchema = HAS_PERMS_BY_NAME(N'dbo', N'SCHEMA', N'ALTER');
SELECT @CanCreateTable = HAS_PERMS_BY_NAME(NULL, N'DATABASE', N'CREATE TABLE');
REVERT;

ALTER ROLE GreenCareAppRole DROP MEMBER GreenCarePermissionProbe;
DROP USER GreenCarePermissionProbe;

IF @CanSelectVotes <> 1 OR @CanInsertVotes <> 1
    THROW 50403, 'Application role is missing required Votes DML permissions.', 1;

IF @CanAlterSchema <> 0 OR @CanCreateTable <> 0
    THROW 50404, 'Application role has unexpected Schema DDL permissions.', 1;

PRINT 'GreenCare application permission verification passed.';
