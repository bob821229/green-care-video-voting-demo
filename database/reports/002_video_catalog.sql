SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
    THROW 51201, 'Videos table is missing.', 1;

SELECT
    Id AS VideoId,
    Number AS WorkNumber,
    Title,
    Team,
    Category,
    SortOrder,
    YoutubeId,
    Poster,
    IsActive,
    CreatedAtUtc,
    UpdatedAtUtc
FROM dbo.Videos
ORDER BY Category, SortOrder, Id;
