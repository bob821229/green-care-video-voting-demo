SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '004')
    THROW 51201, 'Schema version 004 is not installed.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Votes')
      AND name = N'IX_Votes_Environment_Category_Status'
)
    THROW 51202, 'Cross-browser vote guard index is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id
     AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
      AND i.name = N'IX_Votes_Environment_Category_Status'
      AND ic.key_ordinal = 1
      AND COL_NAME(ic.object_id, ic.column_id) = N'IpHash'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id
     AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
      AND i.name = N'IX_Votes_Environment_Category_Status'
      AND ic.key_ordinal = 2
      AND COL_NAME(ic.object_id, ic.column_id) = N'DeviceSignalHash'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id
     AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
      AND i.name = N'IX_Votes_Environment_Category_Status'
      AND ic.key_ordinal = 3
      AND COL_NAME(ic.object_id, ic.column_id) = N'Category'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id
     AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
      AND i.name = N'IX_Votes_Environment_Category_Status'
      AND ic.key_ordinal = 4
      AND COL_NAME(ic.object_id, ic.column_id) = N'Status'
)
OR EXISTS
(
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id
     AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
      AND i.name = N'IX_Votes_Environment_Category_Status'
      AND ic.key_ordinal > 4
)
    THROW 51203, 'Cross-browser vote guard index key columns are incorrect.', 1;

SELECT VersionNumber, Description, AppliedAtUtc, AppliedBy
FROM dbo.SchemaVersions
WHERE VersionNumber = '004';

SELECT
    i.name AS IndexName,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
    ic.key_ordinal AS KeyOrdinal,
    ic.is_included_column AS IsIncludedColumn
FROM sys.indexes i
JOIN sys.index_columns ic
  ON ic.object_id = i.object_id
 AND ic.index_id = i.index_id
WHERE i.object_id = OBJECT_ID(N'dbo.Votes')
  AND i.name = N'IX_Votes_Environment_Category_Status'
ORDER BY ic.is_included_column, ic.key_ordinal, ic.index_column_id;

PRINT 'Cross-browser vote guard verification passed.';
