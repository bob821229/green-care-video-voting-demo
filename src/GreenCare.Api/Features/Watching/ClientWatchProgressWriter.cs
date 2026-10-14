using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Videos;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Watching;

public static class ClientWatchProgressWriter
{
    public static string? ValidateFields(ClientWatchProgressRequest? progress, VideoItem video)
    {
        if (progress is null || progress.VideoId != video.Id ||
            !string.Equals(progress.YoutubeId, video.YoutubeId, StringComparison.Ordinal))
            return "觀看進度資料與作品不符，請重新開啟影片。";
        if (!double.IsFinite(progress.Duration) || progress.Duration is < 10 or > 7200 ||
            !double.IsFinite(progress.WatchedSeconds) || progress.WatchedSeconds < 0 || progress.WatchedSeconds > progress.Duration ||
            !double.IsFinite(progress.LastPosition) || progress.LastPosition < 0 || progress.LastPosition > progress.Duration)
            return "觀看進度資料不正確，請重新開啟影片。";
        return null;
    }

    public static string? ValidateQualified(ClientWatchProgressRequest? progress, VideoItem video)
    {
        var error = ValidateFields(progress, video);
        if (error is not null) return error;
        return progress!.WatchedSeconds / progress.Duration < .8
            ? "請先有效觀看這支影片達 80%。"
            : null;
    }

    public static async Task<WatchSession> WriteAsync(
        GreenCareDbContext db, Guid deviceId, VideoItem video, ClientWatchProgressRequest progress,
        DateTime now, CancellationToken cancellationToken)
    {
        var duration = (decimal)progress.Duration;
        var session = await db.WatchSessions
            .Where(x => x.DeviceId == deviceId && x.VideoId == video.Id &&
                        x.DurationSeconds > duration - 2 && x.DurationSeconds < duration + 2)
            .OrderByDescending(x => x.LastPingAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (session is null)
        {
            session = new WatchSession
            {
                Id = Guid.NewGuid(), DeviceId = deviceId, VideoId = checked((byte)video.Id),
                DurationSeconds = duration, CreatedAtUtc = now
            };
            db.WatchSessions.Add(session);
        }
        session.WatchedSeconds = Math.Max(session.WatchedSeconds, (decimal)progress.WatchedSeconds);
        session.LastPositionSeconds = (decimal)progress.LastPosition;
        session.LastPingAtUtc = now;
        if (session.WatchedSeconds / session.DurationSeconds >= .8m && session.QualifiedAtUtc is null)
            session.QualifiedAtUtc = now;
        return session;
    }
}
