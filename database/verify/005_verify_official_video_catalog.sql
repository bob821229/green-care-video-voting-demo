SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
    THROW 50921, 'dbo.Videos is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '005')
    THROW 50922, 'Dynamic catalog schema 005 is not installed.', 1;
IF (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1) <> 27
    THROW 50923, 'Expected exactly 27 active video rows.', 1;
IF (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'individual' AND IsActive = 1) <> 13
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'team' AND IsActive = 1) <> 14
    THROW 50924, 'Expected 13 active individual and 14 active team videos.', 1;
IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),
            (15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(27)
    ) AS expected(Id)
    LEFT JOIN dbo.Videos AS video ON video.Id = expected.Id AND video.IsActive = 1
    WHERE video.Id IS NULL
)
    THROW 50925, 'Active official catalog must contain every ID from 1 through 27.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Videos
    WHERE IsActive = 1
      AND
      (
           Number <> RIGHT('0' + CONVERT(varchar(2), Id), 2)
        OR (Id BETWEEN 1 AND 13 AND (Category <> 'individual' OR SortOrder <> Id))
        OR (Id BETWEEN 14 AND 27 AND (Category <> 'team' OR SortOrder <> Id - 13))
        OR NULLIF(LTRIM(RTRIM(Title)), N'') IS NULL
        OR NULLIF(LTRIM(RTRIM(Team)), N'') IS NULL
        OR NULLIF(LTRIM(RTRIM(YoutubeId)), '') IS NULL
        OR NULLIF(LTRIM(RTRIM(Poster)), N'') IS NULL
      )
)
    THROW 50926, 'One or more active video rows failed catalog validation.', 1;

SELECT Id, Number, Title, Team, Category, SortOrder, YoutubeId, Poster, IsActive, UpdatedAtUtc
FROM dbo.Videos
WHERE IsActive = 1
ORDER BY Category, SortOrder;

PRINT 'Video catalog verification passed.';

