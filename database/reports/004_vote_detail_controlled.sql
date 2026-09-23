SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Votes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.WatchSessions', N'U') IS NULL
    THROW 51401, 'Required vote-detail tables are missing.', 1;

SELECT
    vote.Id AS VoteId,
    vote.Status,
    vote.CreatedAtUtc,
    vote.CreatedAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Taipei Standard Time' AS CreatedAtTaipei,
    vote.CancelledAtUtc,
    CASE WHEN vote.CancelledAtUtc IS NULL THEN NULL
         ELSE vote.CancelledAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Taipei Standard Time'
    END AS CancelledAtTaipei,
    vote.VoidedAtUtc,
    vote.VoidReason,
    vote.ReplacedByVoteId,
    vote.RiskScore,
    video.Id AS VideoId,
    video.Number AS WorkNumber,
    video.Title,
    video.Team,
    video.Category,
    vote.DeviceId,
    vote.WatchSessionId,
    watch.DurationSeconds,
    watch.WatchedSeconds,
    CAST(watch.WatchedSeconds * 100.0 / NULLIF(watch.DurationSeconds, 0) AS decimal(7,3)) AS WatchedPercentage,
    watch.QualifiedAtUtc,
    CONVERT(varchar(64), vote.IpHash, 2) AS IpHashHex,
    CASE WHEN vote.DeviceSignalHash IS NULL THEN NULL
         ELSE CONVERT(varchar(64), vote.DeviceSignalHash, 2)
    END AS DeviceSignalHashHex
FROM dbo.Votes AS vote
INNER JOIN dbo.Videos AS video ON video.Id = vote.VideoId
INNER JOIN dbo.WatchSessions AS watch ON watch.Id = vote.WatchSessionId
ORDER BY vote.Id;
