using GreenCare.Api.Features.Videos;
using GreenCare.Api.Infrastructure;

namespace GreenCare.Api.Features.ResultData;

public sealed record RankedVideo(
    int Id, string Number, string Title, string Team, string YoutubeId,
    string Poster, string Category, int Votes, int Rank);

public sealed record ResultsGroups(IReadOnlyList<RankedVideo> Individual, IReadOnlyList<RankedVideo> Team);
public sealed record ResultsActivity(string State, DateTime StartsAt, DateTime EndsAt);
public sealed record ResultsPayload(
    bool Published, bool Live, DateTime GeneratedAt, ResultsActivity Activity, ResultsGroups Groups);

public static class ResultsBuilder
{
    public static ResultsPayload Build(
        IReadOnlyList<VideoItem> videos,
        IReadOnlyDictionary<int, int> counts,
        ActivityStatus activity,
        DateTime generatedAtUtc)
    {
        IReadOnlyList<RankedVideo> Rank(string category) => videos
            .Where(x => x.Category == category)
            .Select(x => new { Video = x, Votes = counts.GetValueOrDefault(x.Id) })
            .OrderByDescending(x => x.Votes)
            .ThenBy(x => x.Video.Id)
            .Select((x, index) => new RankedVideo(
                x.Video.Id, x.Video.Number, x.Video.Title, x.Video.Team,
                x.Video.YoutubeId, x.Video.Poster, x.Video.Category, x.Votes, index + 1))
            .ToArray();

        return new ResultsPayload(
            activity.State == ActivityState.Ended,
            activity.State != ActivityState.Ended,
            generatedAtUtc,
            new ResultsActivity(
                activity.State.ToString().ToLowerInvariant(),
                activity.StartsAt.UtcDateTime,
                activity.EndsAt.UtcDateTime),
            new ResultsGroups(Rank("individual"), Rank("team")));
    }
}
