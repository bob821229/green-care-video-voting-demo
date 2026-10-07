using GreenCare.Api.Features.ResultData;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Infrastructure;

namespace GreenCare.Api.Tests.Results;

public sealed class ResultsBuilderTests
{
    [Fact]
    public void Ranks_each_group_by_valid_count_then_video_id()
    {
        var videos = new[]
        {
            Video(3), Video(1), Video(2), Video(17, "team"), Video(16, "team")
        };
        var counts = new Dictionary<int, int>
        {
            [1] = 4,
            [2] = 4,
            [3] = 7,
            [16] = 2,
            [17] = 2
        };
        var activity = new ActivityStatus(
            ActivityState.Active,
            DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
            DateTimeOffset.Parse("2027-01-01T00:00:00Z"));

        var result = ResultsBuilder.Build(videos, counts, activity, DateTime.UnixEpoch);

        Assert.Equal(new[] { 3, 1, 2 }, result.Groups.Individual.Select(x => x.Id));
        Assert.Equal(new[] { 1, 2, 3 }, result.Groups.Individual.Select(x => x.Rank));
        Assert.Equal(new[] { 7, 4, 4 }, result.Groups.Individual.Select(x => x.Votes));
        Assert.Equal(new[] { 16, 17 }, result.Groups.Team.Select(x => x.Id));
    }

    [Fact]
    public void Uses_zero_when_a_video_has_no_valid_votes()
    {
        var activity = new ActivityStatus(
            ActivityState.Ended,
            DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
            DateTimeOffset.Parse("2026-02-01T00:00:00Z"));

        var result = ResultsBuilder.Build(new[] { Video(1) }, new Dictionary<int, int>(), activity, DateTime.UnixEpoch);

        Assert.Equal(0, result.Groups.Individual.Single().Votes);
        Assert.True(result.Published);
        Assert.False(result.Live);
    }

    private static VideoItem Video(int id, string category = "individual") =>
        new(id, id.ToString("00"), $"作品 {id}", $"參賽者 {id}", $"youtube-{id}", $"poster-{id}.jpg", category);
}
