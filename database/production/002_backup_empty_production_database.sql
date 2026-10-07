USE [master];
GO

SET NOCOUNT ON;

DECLARE @DatabaseName sysname = N'GreenCare_Production';
DECLARE @BackupFile nvarchar(4000) = N''; -- Example: D:\SqlBackups\GreenCare_Production_empty_20261007.bak
DECLARE @Confirmation nvarchar(100) = N'';

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    THROW 51002, 'GreenCare_Production does not exist.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@BackupFile)), N'') IS NULL
BEGIN
    THROW 51003, 'Set @BackupFile to an absolute path writable by the SQL Server service account.', 1;
END;

IF @Confirmation <> N'BACKUP EMPTY GREENCARE PRODUCTION DATABASE'
BEGIN
    THROW 51004, 'Confirmation is missing. Set @Confirmation before creating the backup.', 1;
END;

DECLARE @BackupSql nvarchar(max) =
    N'BACKUP DATABASE ' + QUOTENAME(@DatabaseName) +
    N' TO DISK = @Path WITH COPY_ONLY, INIT, CHECKSUM, STATS = 10;';

EXEC sys.sp_executesql
    @BackupSql,
    N'@Path nvarchar(4000)',
    @Path = @BackupFile;

DECLARE @VerifySql nvarchar(max) =
    N'RESTORE VERIFYONLY FROM DISK = @Path WITH CHECKSUM;';

EXEC sys.sp_executesql
    @VerifySql,
    N'@Path nvarchar(4000)',
    @Path = @BackupFile;

SELECT
    d.name AS DatabaseName,
    d.state_desc AS DatabaseState,
    d.recovery_model_desc AS RecoveryModel,
    bs.backup_start_date AS BackupStartedAt,
    bs.backup_finish_date AS BackupFinishedAt,
    bs.backup_size AS BackupSizeBytes,
    bmf.physical_device_name AS BackupFile
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset bs
    ON bs.database_name = d.name
   AND bs.type = 'D'
LEFT JOIN msdb.dbo.backupmediafamily bmf
    ON bmf.media_set_id = bs.media_set_id
WHERE d.name = @DatabaseName
  AND (bs.backup_finish_date IS NULL OR bs.backup_finish_date =
      (SELECT MAX(bs2.backup_finish_date)
       FROM msdb.dbo.backupset bs2
       WHERE bs2.database_name = @DatabaseName
         AND bs2.type = 'D'));

PRINT N'Empty production database backup completed and RESTORE VERIFYONLY passed.';
GO
