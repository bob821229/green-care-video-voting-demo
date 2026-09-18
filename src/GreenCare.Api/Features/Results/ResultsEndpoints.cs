using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.ResultData;

public static class ResultsEndpoints
{
    public static IEndpointRouteBuilder MapGreenCareResultsApi(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/results", GetResultsAsync)
            .RequireRateLimiting(RateLimitPolicies.GeneralIp);
        return endpoints;
    }

    private static async Task<IResult> GetResultsAsync(
        HttpContext context, IResultsCache cache, GreenCareDbContext db,
        IVideoCatalog videos, IActivityService activity, TimeProvider timeProvider,
        CancellationToken cancellationToken)
    {
        context.Response.Headers.CacheControl = "private, max-age=5";
        var payload = await cache.GetOrCreateAsync(async () =>
        {
            var rows = await db.Votes.AsNoTracking()
                .Where(x => x.Status == VoteStatuses.Valid)
                .GroupBy(x => x.VideoId)
                .Select(group => new { VideoId = (int)group.Key, Count = group.Count() })
                .ToListAsync(cancellationToken);
            var counts = rows.ToDictionary(x => x.VideoId, x => x.Count);
            return ResultsBuilder.Build(videos.All, counts, activity.GetStatus(), timeProvider.GetUtcNow().UtcDateTime);
        }, cancellationToken);
        return Results.Ok(payload);
    }
}
