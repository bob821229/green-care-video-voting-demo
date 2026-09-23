using System.Data;
using System.Text.Json;
using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Devices;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Infrastructure;
using GreenCare.Api.Features.ResultData;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Voting;

public static class VotingEndpoints
{
    public static IEndpointRouteBuilder MapGreenCareVotingApi(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/votes", CreateAsync).RequireRateLimiting(RateLimitPolicies.VoteIp);
        endpoints.MapDelete("/api/votes/{id:long}", CancelAsync).RequireRateLimiting(RateLimitPolicies.VoteIp);
        return endpoints;
    }

    private static async Task<IResult> CreateAsync(
        CreateVoteRequest request, HttpContext context, IDeviceIdentityService devices,
        IActivityService activity, ICaptchaVerifier captcha, IRequestWindowLimiter limiter,
        IVoteRiskService riskService, IVideoCatalog catalog, GreenCareDbContext db,
        IResultsCache resultsCache, TimeProvider timeProvider, CancellationToken cancellationToken)
    {
        var deviceId = await devices.GetOrCreateAsync(context, cancellationToken);
        if (activity.GetStatus().State != ActivityState.Active)
            return Results.Json(new { error = "目前不在投票期間。" }, statusCode: StatusCodes.Status403Forbidden);
        if (!limiter.Allow("vote-device", deviceId.ToString("D"), 10)) return RateLimited(context);
        if (!await captcha.VerifyAsync(request.RecaptchaToken, context.Connection.RemoteIpAddress?.ToString(), cancellationToken))
            return Results.Json(new { error = "機器人驗證未通過，請重新勾選。" }, statusCode: StatusCodes.Status403Forbidden);

        var video = await catalog.FindAsync(request.VideoId, cancellationToken);
        if (video is null) return Results.Json(new { error = "找不到這支作品。" }, statusCode: StatusCodes.Status409Conflict);
        var now = timeProvider.GetUtcNow().UtcDateTime;
        var risk = await riskService.EvaluateAsync(deviceId, context.Connection.RemoteIpAddress?.ToString(), request.DeviceSignal, now, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        try
        {
            await LockDeviceAsync(db, deviceId, cancellationToken);
            var activeVotes = await LockActiveVotesAsync(db, deviceId, cancellationToken);
            var error = ValidateVote(activeVotes, video);
            if (error is not null) return await RollbackConflictAsync(transaction, error, cancellationToken);
            var watchId = await FindQualifiedWatchAsync(db, deviceId, video.Id, cancellationToken);
            if (watchId is null) return await RollbackConflictAsync(transaction, "請先有效觀看這支影片達 80%。", cancellationToken);

            var vote = BuildVote(deviceId, video, watchId.Value, risk, now);
            db.Votes.Add(vote);
            AddRiskEventIfNeeded(db, deviceId, risk, now);
            await db.SaveChangesAsync(cancellationToken);
            db.AuditLogs.Add(new AuditLog
            {
                Action = "create_vote", Target = $"vote:{vote.Id}",
                DetailJson = JsonSerializer.Serialize(new { videoId = video.Id, status = risk.Status }), CreatedAtUtc = now
            });
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            resultsCache.Invalidate();
            return Results.Json(new { id = vote.Id, status = vote.Status }, statusCode: StatusCodes.Status201Created);
        }
        catch (DbUpdateException)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Results.Json(new { error = "投票狀態已變更，請重新整理。" }, statusCode: StatusCodes.Status409Conflict);
        }
    }

    private static async Task<IResult> CancelAsync(
        long id, HttpContext context, IDeviceIdentityService devices, IActivityService activity,
        IRequestWindowLimiter limiter, GreenCareDbContext db, IResultsCache resultsCache, TimeProvider timeProvider,
        CancellationToken cancellationToken)
    {
        var deviceId = await devices.GetOrCreateAsync(context, cancellationToken);
        if (activity.GetStatus().State != ActivityState.Active)
            return Results.Json(new { error = "投票截止後不能取消。" }, statusCode: StatusCodes.Status403Forbidden);
        if (!limiter.Allow("vote-device", deviceId.ToString("D"), 10)) return RateLimited(context);
        var now = timeProvider.GetUtcNow().UtcDateTime;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        var vote = await db.Votes
            .FromSqlInterpolated($"SELECT * FROM dbo.Votes WITH (UPDLOCK, ROWLOCK) WHERE Id = {id} AND DeviceId = {deviceId}")
            .SingleOrDefaultAsync(cancellationToken);
        if (vote is null || vote.Status is not (VoteStatuses.Valid or VoteStatuses.Flagged))
            return await RollbackNotFoundAsync(transaction, "找不到可取消的票。", cancellationToken);
        vote.Status = VoteStatuses.Cancelled;
        vote.CancelledAtUtc = now;
        db.AuditLogs.Add(new AuditLog { Action = "cancel_vote", Target = $"vote:{id}", CreatedAtUtc = now });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        resultsCache.Invalidate();
        return Results.Ok(new { ok = true });
    }

    private static Task<List<Vote>> LockActiveVotesAsync(GreenCareDbContext db, Guid deviceId, CancellationToken token) =>
        db.Votes.FromSqlInterpolated($"SELECT * FROM dbo.Votes WITH (UPDLOCK, HOLDLOCK) WHERE DeviceId = {deviceId} AND Status IN ('valid','flagged')")
            .ToListAsync(token);

    private static async Task LockDeviceAsync(GreenCareDbContext db, Guid deviceId, CancellationToken token) =>
        _ = await db.Devices
            .FromSqlInterpolated($"SELECT * FROM dbo.Devices WITH (UPDLOCK, HOLDLOCK) WHERE Id = {deviceId}")
            .SingleAsync(token);

    private static async Task<Guid?> FindQualifiedWatchAsync(GreenCareDbContext db, Guid deviceId, int videoId, CancellationToken token) =>
        await db.WatchSessions.AsNoTracking()
            .Where(x => x.DeviceId == deviceId && x.VideoId == videoId && x.QualifiedAtUtc != null)
            .OrderByDescending(x => x.QualifiedAtUtc).Select(x => (Guid?)x.Id).FirstOrDefaultAsync(token);

    private static string? ValidateVote(List<Vote> votes, VideoItem video)
    {
        if (votes.Any(x => x.VideoId == video.Id)) return "你已經投過這支作品。";
        if (votes.Count(x => x.Category == video.Category) >= 2)
            return $"{(video.Category == VoteCategories.Individual ? "個人組" : "團體組")}已使用兩票，請先取消一票後再投票。";
        return null;
    }

    private static Vote BuildVote(Guid deviceId, VideoItem video, Guid watchId, VoteRisk risk, DateTime now) => new()
    {
        DeviceId = deviceId, VideoId = checked((byte)video.Id), Category = video.Category,
        WatchSessionId = watchId, IpHash = risk.IpHash, DeviceSignalHash = risk.DeviceSignalHash,
        RiskScore = risk.Score, Status = risk.Status, CreatedAtUtc = now
    };

    private static void AddRiskEventIfNeeded(GreenCareDbContext db, Guid deviceId, VoteRisk risk, DateTime now)
    {
        if (risk.Score == 0) return;
        db.RiskEvents.Add(new RiskEvent
        {
            DeviceId = deviceId, IpHash = risk.IpHash, Kind = "vote_risk",
            DetailJson = JsonSerializer.Serialize(new { score = risk.Score, recentIp = risk.RecentIp, others = risk.OtherDevices }),
            CreatedAtUtc = now
        });
    }

    private static IResult RateLimited(HttpContext context)
    {
        context.Response.Headers.RetryAfter = "60";
        return Results.Json(new { error = "操作過於頻繁，請稍後再試。" }, statusCode: 429);
    }

    private static async Task<IResult> RollbackConflictAsync(Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction tx, string error, CancellationToken ct)
    { await tx.RollbackAsync(ct); return Results.Conflict(new { error }); }
    private static async Task<IResult> RollbackNotFoundAsync(Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction tx, string error, CancellationToken ct)
    { await tx.RollbackAsync(ct); return Results.NotFound(new { error }); }
}
