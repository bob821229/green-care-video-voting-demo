SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
    THROW 50921, 'dbo.Videos is missing.', 1;
IF (SELECT COUNT(*) FROM dbo.Videos) <> 30
    THROW 50922, 'Expected exactly 30 video rows.', 1;
IF (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'individual' AND Id BETWEEN 1 AND 15) <> 15
   OR (SELECT COUNT(*) FROM dbo.Videos WHERE Category = 'team' AND Id BETWEEN 16 AND 30) <> 15
    THROW 50923, 'Expected 15 individual and 15 team videos.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Videos
    WHERE Number <> RIGHT('0' + CONVERT(varchar(2), Id), 2)
       OR (Category = 'individual' AND SortOrder <> Id)
       OR (Category = 'team' AND SortOrder <> Id - 15)
       OR IsActive <> 1
       OR NULLIF(LTRIM(RTRIM(Title)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(Team)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(YoutubeId)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(Poster)), N'') IS NULL
)
    THROW 50924, 'One or more video rows failed catalog validation.', 1;

SELECT Id, Number, Title, Team, Category, SortOrder, YoutubeId, Poster, IsActive, UpdatedAtUtc
FROM dbo.Videos
ORDER BY Id;

PRINT 'Video catalog verification passed.';

