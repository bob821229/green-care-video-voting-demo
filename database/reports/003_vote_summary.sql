SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
    THROW 51301, 'Videos or Votes table is missing.', 1;

WITH StatusCounts AS
(
    SELECT
        video.Id AS VideoId,
        video.Number AS WorkNumber,
        video.Title,
        video.Team,
        video.Category,
        video.SortOrder,
        video.IsActive,
        SUM(CASE WHEN vote.Status = 'valid' THEN 1 ELSE 0 END) AS ValidVotes,
        SUM(CASE WHEN vote.Status = 'flagged' THEN 1 ELSE 0 END) AS FlaggedVotes,
        SUM(CASE WHEN vote.Status = 'cancelled' THEN 1 ELSE 0 END) AS CancelledVotes,
        SUM(CASE WHEN vote.Status = 'void' THEN 1 ELSE 0 END) AS VoidVotes,
        COUNT(vote.Id) AS TotalVoteRecords
    FROM dbo.Videos AS video
    LEFT JOIN dbo.Votes AS vote ON vote.VideoId = video.Id
    GROUP BY
        video.Id, video.Number, video.Title, video.Team,
        video.Category, video.SortOrder, video.IsActive
),
Ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY Category
            ORDER BY ValidVotes DESC, VideoId ASC
        ) AS DisplayRank,
        SUM(ValidVotes) OVER (PARTITION BY Category) AS CategoryValidVotes
    FROM StatusCounts
)
SELECT
    Category,
    DisplayRank,
    VideoId,
    WorkNumber,
    Title,
    Team,
    ValidVotes,
    CAST(
        CASE WHEN CategoryValidVotes = 0 THEN 0
             ELSE ValidVotes * 100.0 / CategoryValidVotes
        END AS decimal(6,2)
    ) AS ValidVotePercentage,
    FlaggedVotes,
    CancelledVotes,
    VoidVotes,
    TotalVoteRecords,
    IsActive
FROM Ranked
ORDER BY Category, DisplayRank, VideoId;
