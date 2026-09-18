using System.Data;
using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Devices;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Features.Watching;
using GreenCare.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features;

public static class PublicApiEndpoints
{
    private const string WatchTokenPurpose = "watch-session-v1";

    public static IEndpointRouteBuilder MapGreenCarePublicApi(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/bootstrap", BootstrapAsync)
            .RequireRateLimiting(RateLimitPolicies.GeneralIp);
        endpoints.MapPost("/api/watch/start", StartWatchAsync)
            .RequireRateLimiting(RateLimitPolicies.WatchStartIp);
        endpoints.MapPost("/api/watch/progress", UpdateProgressAsync)
            .RequireRateLimiting(RateLimitPolicies.WatchProgressIp);
        return endpoints;
    }

    private static async Task<IResult> BootstrapAsync(
        HttpContext context,
        IDeviceIdentityService devices,
        IVideoCatalog videos,
        IActivityService activityService,
        GreenCareDbContext db,
        IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        var deviceId = await devices.GetOrCreateAsync(context, cancellationToken);
        var votes = await db.Votes.AsNoTracking()
            .Where(x => x.DeviceId == deviceId && (x.Status == VoteStatuses.Valid || x.Status == VoteStatuses.Flagged))
            .OrderBy(x => x.CreatedAtUtc)
            .Select(x => new { x.Id, x.VideoId, x.Category, x.Status, x.CreatedAtUtc })
            .ToListAsync(cancellationToken);
        var progress = await db.WatchSessions.AsNoTracking()
            .Where(x => x.DeviceId == deviceId)
            .GroupBy(x => x.VideoId)
            .Select(group => new
            {
                VideoId = group.Key,
                Ratio = group.Max(x => x.WatchedSeconds / x.DurationSeconds),
                Qualified = group.Any(x => x.QualifiedAtUtc != null) ? 1 : 0
            })
            .ToListAsync(cancellationToken);
        var individualUsed = votes.Count(x => x.Category == VoteCategories.Individual);
        var teamUsed = votes.Count(x => x.Category == VoteCategories.Team);
        var activity = activityService.GetStatus();

        return Results.Ok(new
        {
            videos = videos.All.Select(x => new
            {
                x.Id, x.Number, x.Title, x.Team, x.YoutubeId, x.Poster, x.Category
            }),
            votes,
            progress,
            limits = new { individual = 2, team = 2 },
            remaining = new { individual = 2 - individualUsed, team = 2 - teamUsed },
            activity = new
            {
                state = activity.State.ToString().ToLowerInvariant(),
                startsAt = activity.StartsAt.UtcDateTime,
                endsAt = activity.EndsAt.UtcDateTime
            },
            recaptchaSiteKey = configuration["Captcha:SiteKey"] ?? string.Empty,
            demo = false
        });
    }

    private static async Task<IResult> StartWatchAsync(
        WatchStartRequest request,
        HttpContext context,
        IDeviceIdentityService devices,
        IVideoCatalog videos,
        IRequestWindowLimiter limiter,
        ISignedTokenService tokens,
        TimeProvider timeProvider,
        GreenCareDbContext db,
        CancellationToken cancellationToken)
    {
        var deviceId = await devices.GetOrCreateAsync(context, cancellationToken);
        if (!limiter.Allow("watch-start-device", deviceId.ToString("D"), 12)) return RateLimited(context);
        if (!videos.Contains(request.VideoId) || !double.IsFinite(request.Duration) || request.Duration is < 10 or > 7200)
            return Results.BadRequest(new { error = "影片資料不正確。" });

        var duration = (decimal)request.Duration;
        var cutoff = timeProvider.GetUtcNow().UtcDateTime.AddMinutes(-30);
        var recent = await db.WatchSessions.AsNoTracking()
            .Where(x => x.DeviceId == deviceId && x.VideoId == request.VideoId &&
                        x.DurationSeconds > duration - 2 && x.DurationSeconds < duration + 2 &&
                        x.LastPingAtUtc >= cutoff)
            .OrderByDescending(x => x.LastPingAtUtc)
            .Select(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (recent != Guid.Empty)
            return Results.Ok(new WatchStartResponse(tokens.Create(WatchTokenPurpose, recent), true));

        var now = timeProvider.GetUtcNow().UtcDateTime;
        var session = new WatchSession
        {
            Id = Guid.NewGuid(), DeviceId = deviceId, VideoId = checked((byte)request.VideoId),
            DurationSeconds = duration, WatchedSeconds = 0, LastPositionSeconds = 0,
            LastPingAtUtc = now, CreatedAtUtc = now
        };
        db.WatchSessions.Add(session);
        await db.SaveChangesAsync(cancellationToken);
        return Results.Ok(new WatchStartResponse(tokens.Create(WatchTokenPurpose, session.Id), false));
    }

    private static async Task<IResult> UpdateProgressAsync(
        WatchProgressRequest request,
        HttpContext context,
        IDeviceIdentityService devices,
        IRequestWindowLimiter limiter,
        ISignedTokenService tokens,
        TimeProvider timeProvider,
        GreenCareDbContext db,
        CancellationToken cancellationToken)
    {
        var deviceId = await devices.GetOrCreateAsync(context, cancellationToken);
        if (!limiter.Allow("watch-progress-device", deviceId.ToString("D"), 60)) return RateLimited(context);
        if (!tokens.TryRead(WatchTokenPurpose, request.SessionId, out var sessionId))
            return Results.NotFound(new { error = "觀看紀錄已失效，請重新播放。" });
        if (!limiter.Allow("watch-progress-session", sessionId.ToString("D"), 20)) return RateLimited(context);

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        var session = await db.WatchSessions
            .FromSqlInterpolated($"SELECT * FROM dbo.WatchSessions WITH (UPDLOCK, ROWLOCK) WHERE Id = {sessionId} AND DeviceId = {deviceId}")
            .SingleOrDefaultAsync(cancellationToken);
        if (session is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Results.NotFound(new { error = "觀看紀錄已失效，請重新播放。" });
        }

        var now = timeProvider.GetUtcNow().UtcDateTime;
        var decision = WatchProgressEvaluator.Evaluate(
            session.DurationSeconds,
            session.WatchedSeconds,
            session.LastPositionSeconds,
            (now - session.LastPingAtUtc).TotalSeconds,
            request);
        if (decision.Restarted)
        {
            session.LastPositionSeconds = decision.LastPositionSeconds;
            session.LastPingAtUtc = now;
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Results.Ok(new { ratio = session.WatchedSeconds / session.DurationSeconds, qualified = session.QualifiedAtUtc != null, restarted = true });
        }
        if (decision.Throttled)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Results.Ok(new { ratio = session.WatchedSeconds / session.DurationSeconds, qualified = session.QualifiedAtUtc != null, throttled = true });
        }

        session.WatchedSeconds = decision.WatchedSeconds;
        session.LastPositionSeconds = decision.LastPositionSeconds;
        session.LastPingAtUtc = now;
        if (decision.Qualified && session.QualifiedAtUtc is null) session.QualifiedAtUtc = now;
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Results.Ok(new { ratio = session.WatchedSeconds / session.DurationSeconds, qualified = decision.Qualified });
    }

    private static IResult RateLimited(HttpContext context)
    {
        context.Response.Headers.RetryAfter = "60";
        return Results.Json(new { error = "操作過於頻繁，請稍後再試。" }, statusCode: StatusCodes.Status429TooManyRequests);
    }
}
